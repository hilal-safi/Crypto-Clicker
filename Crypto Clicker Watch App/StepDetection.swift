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
    @Published var lastStepCount: Int = 0
    @Published var totalCoinsFromSteps: Decimal = 0

    private let stepsKey = "lastStepCount"
    private let coinsKey = "totalCoinsFromSteps"
    
    // We’ll store our anchored query’s anchor here.
    private var anchor: HKQueryAnchor?

    // Also keep your observer query + optional timer if you want:
    private var stepUpdateTimer: Timer?

    init() {
        loadSavedData()           // Load previously saved steps and coins
        loadAnchorFromDefaults()  // Load the last known anchor
        requestAuthorization()
        // (Optional) startRepeatingFetch() if you still want a fallback timer
    }
    
    deinit {
        stepUpdateTimer?.invalidate()
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let readTypes = Set([stepType])
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("[StepDetection] HealthKit auth error: \(error)")
            } else if success {
                print("[StepDetection] HealthKit authorized for stepCount")
                
                // Start the observer + anchored queries
                Task { @MainActor in
                    self.startObservingSteps()
                    self.startAnchoredQuery()
                }
            }
        }
    }
    
    // MARK: - Observer Query (background notifications)

    private func startObservingSteps() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("[StepDetection] Observer Query error: \(error)")
                return
            }
            // Whenever new data arrives, run the anchored query to fetch actual samples:
            Task { @MainActor in
                await self?.runAnchoredQuery() // We’ll define below
            }
        }
        
        healthStore.execute(query)

        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if success {
                print("[StepDetection] Background delivery enabled for stepCount.")
            } else if let error = error {
                print("[StepDetection] enableBackgroundDelivery error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Anchored Query

    /// Creates and executes our anchored query for step samples.
    private func startAnchoredQuery() {
        
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        // If anchor is nil, it means we're starting fresh.
        let newQuery = HKAnchoredObjectQuery(type: stepType,
                                             predicate: nil,
                                             anchor: anchor,
                                             limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, _, newAnchor, error in
            guard let self = self else { return }
            if let error = error {
                print("[StepDetection] Anchored Query error: \(error)")
                return
            }
            Task { @MainActor in
                self.processNewSamples(samplesOrNil)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }
        
        // We also set updateHandler so it’s called whenever new data arrives while this query is active:
        newQuery.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("[StepDetection] Anchored Query update error: \(error)")
                return
            }
            Task { @MainActor in
                self.processNewSamples(samplesOrNil)
                self.anchor = newAnchor
                self.saveAnchorToDefaults(newAnchor)
            }
        }

        healthStore.execute(newQuery)
    }
    
    /// Tells HealthKit to re-run the anchored query to catch up on new data.
    @MainActor
    private func runAnchoredQuery() {
        // We'll just re-launch the same anchored logic by starting fresh:
        startAnchoredQuery()
    }
    
    /// Processes newly returned samples from the anchored query.
    @MainActor
    private func processNewSamples(_ samplesOrNil: [HKSample]?) {
        
        guard let samples = samplesOrNil else { return }
        
        var totalNewSteps = 0
        
        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            // Double-check it's stepCount
            if quantitySample.quantityType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                let stepValue = Int(quantitySample.quantity.doubleValue(for: .count()))
                totalNewSteps += stepValue
            }
        }
        
        if totalNewSteps > 0 {
            
            if self.anchor == nil {
                
                // First run: Initialize lastStepCount without incrementing coins
                self.lastStepCount = totalNewSteps
                print("[StepDetection] Initializing step count to \(totalNewSteps). No coins added.")
                
                // Send initialization message to phone
                WatchSessionManager.shared.initializeSteps(totalNewSteps)
                
            } else {
                
                // Subsequent runs: Increment coins based on new steps
                print("[StepDetection] Anchored Query found \(totalNewSteps) new step(s).")
                
                let delta = totalNewSteps
                self.lastStepCount += delta
                self.incrementCoinsFromSteps(delta)
            }
        }
    }
    
    // MARK: - (Optional) Repeating Timer

    /// If you want an additional fallback that re-checks with HKStatisticsQuery,
    /// you can keep or remove this. For example, if anchored query isn't working reliably:
    private func startRepeatingFetch() {
        stepUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // A fallback approach
            Task { @MainActor in
                self.fetchStepsSinceMidnight()
            }
        }
    }

    /// This uses a simple HKStatisticsQuery. You might not need it now that you have an anchored query.
    func fetchStepsSinceMidnight() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, stats, error in
            Task { @MainActor in
                if let sum = stats?.sumQuantity() {
                    let stepsSoFar = Int(sum.doubleValue(for: HKUnit.count()))
                    let delta = stepsSoFar - (self?.lastStepCount ?? 0) // Corrected optional unwrapping
                    if delta > 0 {
                        self?.lastStepCount = stepsSoFar
                        self?.incrementCoinsFromSteps(delta)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Step & Coin Increments

    func incrementCoinsFromSteps(_ steps: Int) {
        let coinsEarned = Decimal(steps) / 100 // 1 coin per 100 steps (example)
        totalCoinsFromSteps += coinsEarned
        
        // Send step data to the phone
        WatchSessionManager.shared.addSteps(steps)
        
        // Persist locally
        saveData()
    }
    
    // MARK: - Persistence

    func saveData() {
        UserDefaults.standard.set(lastStepCount, forKey: stepsKey)
        UserDefaults.standard.set(totalCoinsFromSteps as NSNumber, forKey: coinsKey)
    }
    
    private func loadSavedData() {
        lastStepCount = UserDefaults.standard.integer(forKey: stepsKey)
        if let coins = UserDefaults.standard.object(forKey: coinsKey) as? NSNumber {
            totalCoinsFromSteps = Decimal(coins.doubleValue)
        }
    }

    // MARK: - Anchor Persistence

    /// Save the HKQueryAnchor so we can pick up from the last known sample next time the app runs.
    @MainActor
    private func saveAnchorToDefaults(_ anchor: HKQueryAnchor?) {
        guard let anchor = anchor else { return }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false)
        UserDefaults.standard.set(data, forKey: "HKAnchorData")
    }
    
    private func loadAnchorFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "HKAnchorData"),
              let savedAnchor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HKQueryAnchor else {
            return
        }
        self.anchor = savedAnchor
    }
}
