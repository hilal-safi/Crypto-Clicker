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

    init() {
        loadAnchorFromDefaults()
        let savedCumulative = UserDefaults.standard.integer(forKey: "cumulativeStepsKey")
        cumulativeSteps = savedCumulative // Load persistent cumulativeSteps
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
        
        let query = HKAnchoredObjectQuery(type: stepType,
                                          predicate: nil,
                                          anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { [weak self] _, samples, deleted, newAnchor, error in
            
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
        
        let query = HKAnchoredObjectQuery(type: stepType,
                                          predicate: nil,
                                          anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { [weak self] _, samples, deleted, newAnchor, error in
            
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

        var totalNewSteps = 0

        for sample in samples {
            
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            
            if quantitySample.quantityType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                let stepsInSample = Int(quantitySample.quantity.doubleValue(for: .count()))
                totalNewSteps += stepsInSample
            }
        }

        let currentTotalSteps = totalNewSteps
        let newStepsToAward = currentTotalSteps - cumulativeSteps

        // 1) Update cumulativeSteps in memory
        cumulativeSteps = currentTotalSteps

        // 2) **Persist** cumulativeSteps so it survives app restarts
        UserDefaults.standard.set(cumulativeSteps, forKey: "cumulativeStepsKey")

        // 3) Award new steps
        if newStepsToAward > 0 {
            print("[StepDetection] New steps to award: \(newStepsToAward)")
            Task { @MainActor in
                WatchSessionManager.shared.addSteps(newStepsToAward)
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
