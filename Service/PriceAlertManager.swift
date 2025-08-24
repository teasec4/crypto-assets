//
//  PriceAlertManager.swift
//  cryptobalanceV1
//
//  Created by Максим Ковалев on 8/24/25.
//
import Foundation
import SwiftData
import UserNotifications
import SwiftUI

class PriceAlertManager{
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            print("Notification permission request result: \(granted ? "Granted" : "Denied")")
        } catch {
            print("Failed to request notification permission: \(error)")
        }
    }
    
    func checkPriceAlerts(prices: [String: Double]) async {
        print("Checking price alerts with prices: \(prices)")
        let fetchDescriptor = FetchDescriptor<PriceAlert>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let alerts = try modelContext.fetch(fetchDescriptor)
            print("Fetched \(alerts.count) price alerts: \(alerts.map { "\($0.symbol): \($0.signedPercentage)% at $\($0.referencePrice)" })")
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            print("Notification settings: authorizationStatus=\(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus != .authorized {
                print("Notifications not authorized. Requesting permission again.")
                await requestNotificationPermission()
                return
            }
            for alert in alerts {
                guard let currentPrice = prices[alert.coinId] else {
                    print("No price found for coinId: \(alert.coinId)")
                    continue
                }
                let changePercent = (currentPrice - alert.referencePrice) / alert.referencePrice * 100
                print("Alert for \(alert.symbol): currentPrice=\(currentPrice), referencePrice=\(alert.referencePrice), changePercent=\(changePercent), threshold=\(alert.signedPercentage)")
                let shouldTrigger = (alert.signedPercentage > 0 && changePercent >= alert.signedPercentage) ||
                (alert.signedPercentage < 0 && changePercent <= alert.signedPercentage)
                if shouldTrigger {
                    let content = UNMutableNotificationContent()
                    content.title = "Price Alert: \(alert.symbol)"
                    content.body = "\(alert.symbol) price changed by \(changePercent.formatted(.number.precision(.fractionLength(1))))% to $\(currentPrice, default: "%.2f") (Alert set at $\(alert.referencePrice, default: "%.2f"))."
                    content.sound = .default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    do {
                        try await center.add(request)
                        print("Notification scheduled for \(alert.symbol): \(changePercent.formatted(.number.precision(.fractionLength(1))))% change")
                        modelContext.delete(alert) // Delete alert after triggering
                        do {
                            try modelContext.save()
                            print("Deleted triggered price alert and saved context")
                        } catch {
                            print("Failed to save context after deleting price alert: \(error)")
                        }
                    } catch {
                        print("Failed to schedule notification for \(alert.symbol): \(error)")
                    }
                } else {
                    print("Alert for \(alert.symbol) not triggered: changePercent=\(changePercent) does not meet threshold=\(alert.signedPercentage)")
                }
            }
        } catch {
            print("Failed to fetch alerts: \(error)")
        }
    }
}
