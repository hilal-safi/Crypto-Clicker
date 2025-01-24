//
//  StepDetection.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-04.
//

import Foundation
import HealthKit
import SwiftUI

@MainActor
class StepDetection: ObservableObject {
    
    private let healthStore = HKHealthStore()
    
    // Holds the total steps we’ve awarded so far
    private var cumulativeSteps: Int = 0
    
    private var anchor: HKQueryAnchor?
    private var stepFetchTimer: Timer?
    
    // For error handling
    @Published var errorWrapper: ErrorWrapper?
    
    // Maps sample UUID => the furthest endDate we have already awarded. This is more fine-grained than a single processedSampleIDs set.
    private var sampleProgress: [UUID: Date] = [:]
    
    // Keep your global lastProcessedEndDate if you prefer a universal floor
    private var lastProcessedEndDate: Date? {
        didSet {
            if let date = lastProcessedEndDate {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastProcessedEndDate")
            }
        }
    }

    init() {
        
        loadAnchorFromDefaults() // Load any saved anchor for HealthKit queries.
        loadLastProcessedEndDate() // Load the last processed end date to avoid duplicate processing.
        loadSampleProgress() // load your processed sample IDs

        // Load cumulative steps from persistent storage.
        let savedCumulative = UserDefaults.standard.integer(forKey: "cumulativeStepsKey")
        cumulativeSteps = savedCumulative

        // Request authorization for HealthKit.
        requestAuthorization()
    }
    
    // MARK: - Authorization
    private func requestAuthorization() {
        
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let readTypes: Set = [stepType]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in

            // If there's an error from HealthKit:
            if let error = error {
                
                // Move to main thread to set errorWrapper
                DispatchQueue.main.async {
                    
                    self.errorWrapper = ErrorWrapper(
                        error: error,
                        guidance: "Ensure HealthKit permissions are enabled for Step Count."
                    )
                }
                return
            }

            // If user grants permission:
            if success {
                
                print("[StepDetection] HealthKit authorized for stepCount")
                Task { @MainActor in
                    self.startObservingSteps(for: stepType)
                }
                
            } else {
                
                // If user explicitly denies permission:
                DispatchQueue.main.async {
                    
                    self.errorWrapper = ErrorWrapper(
                        error: NSError(domain: "HealthKitAuth", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "HealthKit authorization denied."
                        ]),
                        guidance: "Please enable HealthKit access for Step Count in Settings."
                    )
                }
            }
        }
    }
    
    // MARK: - Observing + Anchored Query
    private func startObservingSteps(for stepType: HKQuantityType) {
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            
            if let error = error {
                print("[StepDetection] Observer Query error: \(error)")
                completionHandler()  // Signal completion even on error
                return
            }
            completionHandler()
        }
        healthStore.execute(query)
    }
    
    private func startAnchoredQuery(for stepType: HKQuantityType) {
        
        let predicate: NSPredicate? = lastProcessedEndDate.map { date in
            NSPredicate(format: "endDate > %@", date as NSDate)
        }

        let query = HKAnchoredObjectQuery(type: stepType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) {
            
            [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }

            if let error = error {
                // If an error occurs, wrap it
                DispatchQueue.main.async {
                    self.errorWrapper = ErrorWrapper(
                        error: error,
                        guidance: "Failed to run anchored query for steps."
                    )
                }
                return
            }

            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }

        // Called whenever new samples arrive in the background
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }

            if let error = error {
                
                DispatchQueue.main.async {
                    
                    self.errorWrapper = ErrorWrapper(
                        error: error,
                        guidance: "Anchored Query update failed while fetching new steps."
                    )
                }
                return
            }

            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }
        healthStore.execute(query)
    }

    private func runAnchoredQuery(for stepType: HKQuantityType) {
        
        let query = HKAnchoredObjectQuery(type: stepType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) {
            
            [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }

            if let error = error {
                // Updated to set errorWrapper
                DispatchQueue.main.async {
                    self.errorWrapper = ErrorWrapper(
                        error: error,
                        guidance: "Failed to retrieve new step samples from HealthKit."
                    )
                }
                return
            }

            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }

        // Repeat in updateHandler:
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }

            if let error = error {
                
                DispatchQueue.main.async {
                    
                    self.errorWrapper = ErrorWrapper(
                        error: error,
                        guidance: "Anchored Query update failed while fetching new steps."
                    )
                }
                return
            }

            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }

        healthStore.execute(query)
    }
    
    // MARK: - Process Samples
    private func processNewSamples(_ samplesOrNil: [HKSample]?) {
        
        guard let samples = samplesOrNil else { return }
        
        var newlyAwardedSteps = 0
        var newestEnd: Date?

        for sample in samples {
            
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            
            // Skip if sample is already processed
            if let lastProcessed = sampleProgress[quantitySample.uuid],
               lastProcessed >= quantitySample.endDate {
                continue
            }
            
            let sampleStart = quantitySample.startDate
            let sampleEnd = quantitySample.endDate
            let totalSampleSteps = Int(quantitySample.quantity.doubleValue(for: .count()))
            
            // Skip samples entirely before lastProcessedEndDate
            if let lastDate = lastProcessedEndDate, sampleEnd <= lastDate {
                continue
            }
            
            // Award the full steps from this sample
            newlyAwardedSteps += totalSampleSteps
            
            // Update progress for this sample
            sampleProgress[quantitySample.uuid] = sampleEnd
            
            // Update newestEnd to track furthest processed date
            if newestEnd == nil || sampleEnd > newestEnd! {
                newestEnd = sampleEnd
            }
        }
        
        // Apply correction factor to compensate for overcounting
        newlyAwardedSteps = Int(Double(newlyAwardedSteps) * 0.6)

        if newlyAwardedSteps > 0 {
            //print("[StepDetection] Awarding \(newlyAwardedSteps) new steps.")
            cumulativeSteps += newlyAwardedSteps
            UserDefaults.standard.set(cumulativeSteps, forKey: "cumulativeStepsKey")
            
            // Notify phone about awarded steps
            Task { @MainActor in
                WatchSessionManager.shared.addSteps(newlyAwardedSteps)
            }
        }

        // Update global lastProcessedEndDate
        if let endDate = newestEnd, endDate > (lastProcessedEndDate ?? .distantPast) {
            lastProcessedEndDate = endDate
        }
        
        // Save progress
        saveSampleProgress()
    }
    
    // When user opens app, get steps
    func fetchStepsNow() {
        
        Task { @MainActor in
            // For simplicity, assume we always want stepCount
            guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                return
            }
            //print("[StepDetection] fetchStepsNow => running anchored query immediately.")
            self.runAnchoredQuery(for: stepType)
        }
    }
    
    // MARK: - Anchor Persistence
    private func saveAnchorToDefaults(_ anchor: HKQueryAnchor?) {
        
        guard let anchor = anchor else { return }
        
        let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false)
        UserDefaults.standard.set(data, forKey: "HKAnchorData")
    }
    
    private func loadAnchorFromDefaults() {
        
        guard
            let data = UserDefaults.standard.data(forKey: "HKAnchorData"),
            let savedAnchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
                
        else {
            return
        }
        self.anchor = savedAnchor
    }
    
    private func loadLastProcessedEndDate() {
        // Retrieve the last processed end date from UserDefaults.
        let savedEndDate = UserDefaults.standard.double(forKey: "lastProcessedEndDate")
        if savedEndDate > 0 {
            self.lastProcessedEndDate = Date(timeIntervalSince1970: savedEndDate)
            print("[StepDetection] Loaded last processed end date: \(self.lastProcessedEndDate!)")
        } else {
            self.lastProcessedEndDate = nil
            print("[StepDetection] No last processed end date found, starting fresh.")
        }
    }
    
    // Persist sampleProgress dictionary as [UUIDString: TimeIntervalSince1970]
    private func saveSampleProgress() {
        
        let dict = sampleProgress.reduce(into: [String: TimeInterval]()) {
            $0[$1.key.uuidString] = $1.value.timeIntervalSince1970
        }
        UserDefaults.standard.set(dict, forKey: "sampleProgressDict")
    }

    // Load sampleProgress dictionary from UserDefaults
    private func loadSampleProgress() {
        
        guard let dict = UserDefaults.standard.dictionary(forKey: "sampleProgressDict") as? [String: TimeInterval]
            else { return }
        
        // Convert back to [UUID: Date]
        for (uuidString, interval) in dict {
            
            if let uuid = UUID(uuidString: uuidString) {
                sampleProgress[uuid] = Date(timeIntervalSince1970: interval)
            }
        }
    }
}
