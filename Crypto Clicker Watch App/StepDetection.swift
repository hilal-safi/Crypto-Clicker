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
    
    // To prevent overcounting of steps
    private var lastProcessedEndDate: Date? {
        didSet {
            // Persist in UserDefaults so we don't re-award after app restarts
            if let date = lastProcessedEndDate {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastProcessedEndDate")
            }
        }
    }

    init() {
        loadAnchorFromDefaults()
        
        let savedCumulative = UserDefaults.standard.integer(forKey: "cumulativeStepsKey")
        cumulativeSteps = savedCumulative
        
        // Load last processed end-date (to skip awarding duplicates)
        let savedEndDate = UserDefaults.standard.double(forKey: "lastProcessedEndDate")
        if savedEndDate > 0 {
            self.lastProcessedEndDate = Date(timeIntervalSince1970: savedEndDate)
        }
        
        requestAuthorization()
    }

    // MARK: - Authorization
    private func requestAuthorization() {
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let readTypes: Set = [stepType]
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            
            if let error = error {
                print("[StepDetection] HealthKit auth error: \(error)")
                
            } else if success {
                print("[StepDetection] HealthKit authorized for stepCount")
                
                Task { @MainActor in
                    self.enableBackgroundDelivery(for: stepType)
                    self.startObservingSteps(for: stepType)
                    self.startAnchoredQuery(for: stepType)
                }
                
            } else {
                print("[StepDetection] HealthKit authorization failed.")
            }
        }
    }
    
    // MARK: - Observing + Anchored Query
    private func startObservingSteps(for stepType: HKQuantityType) {
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            
            if let error = error {
                print("[StepDetection] Observer Query error: \(error)")
                return
            }
            
            Task { @MainActor in
                self?.runAnchoredQuery(for: stepType)
            }
        }
        healthStore.execute(query)
    }
    
    private func startAnchoredQuery(for stepType: HKQuantityType) {
        
        let query = HKAnchoredObjectQuery(type: stepType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) {
            [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("[StepDetection] Anchored Query error: \(error)")
                return
            }

            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }
        
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("[StepDetection] Anchored Query update error: \(error)")
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
                print("[StepDetection] Anchored Query error: \(error)")
                return
            }
            
            Task { @MainActor in
                self.processNewSamples(samples)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }
        
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("[StepDetection] Anchored Query update error: \(error)")
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

        var batchSteps = 0
        var newestEndDate: Date? = nil

        // Use a Set to track processed sample IDs (ensures no duplicate samples are processed)
        var processedSampleIDs = Set<String>()

        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }

            // Check if the sample has been processed before
            if processedSampleIDs.contains(quantitySample.uuid.uuidString) {
                continue
            }
            
            // Add sample UUID to the processed set
            processedSampleIDs.insert(quantitySample.uuid.uuidString)

            if quantitySample.quantityType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                let endDate = quantitySample.endDate

                // Skip if sample ends on/before lastProcessedEndDate
                if let lastDate = lastProcessedEndDate, endDate <= lastDate {
                    continue
                }

                let stepsInSample = Int(quantitySample.quantity.doubleValue(for: .count()))
                batchSteps += stepsInSample

                // Track the farthest endDate we've seen
                if newestEndDate == nil || endDate > newestEndDate! {
                    newestEndDate = endDate
                }
            }
        }

        if batchSteps > 0 {
            print("[StepDetection] Detected new steps = \(batchSteps). Sending to phone.")
            cumulativeSteps += batchSteps
            UserDefaults.standard.set(cumulativeSteps, forKey: "cumulativeStepsKey")

            // Update lastProcessedEndDate to skip these samples in the future
            if let endDate = newestEndDate {
                lastProcessedEndDate = endDate
            }

            // Send only this batch to the phone
            Task { @MainActor in
                WatchSessionManager.shared.addSteps(batchSteps)
            }
        }
    }
    
    // MARK: - Background Delivery
    private func enableBackgroundDelivery(for sampleType: HKSampleType) {
        
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
            
            if success {
                print("[StepDetection] Background delivery enabled for \(sampleType.identifier).")
                
            } else if let error = error {
                print("[StepDetection] Background delivery error: \(error.localizedDescription)")
            }
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
}
