# 💰 Crypto Portfolio Tracker

An **iOS application for tracking a cryptocurrency portfolio with CoinGecko API integration**.  
Users can add transactions, view total asset value, track profit/loss, and configure price alerts.  
All data is stored locally with **SwiftData** and synchronized when fetching updated prices from the network.

---

## ✨ Features
- ➕ Add and manage transactions  
- 📊 View total portfolio value, invested amount, and profit/loss  
- 🔔 Configure price alerts with local notifications  
- 💾 Offline persistence with SwiftData  
- 🔄 Automatic refresh of market data every 5 minutes  
- ⚠️ Error handling with retry option  
- 📱 Responsive UI built with SwiftUI  

---

## ⚙️ Key Implementation Details
- **MVVM architecture** – clean separation of business logic and views (`SwiftUI + Combine`).  
- **SwiftData** – local persistence with reactive queries (`@Query`, `@Environment(\.modelContext)`).  
- **URLSession** – async/await networking for CoinGecko API.  
- **NotificationCenter / UserNotifications** – local push notifications for price alerts.  
- **AppStorage** – persist user section visibility (Price / Assets / Alerts).  
- **Combine Timer** – top-down timer using `Timer.publish` for auto-refresh every 5 minutes.  
- **UserDefaults caching** – cache coins and prices to reduce API load.  
- **Batch requests** – fetch prices in batches of 50 IDs to avoid API rate limits.  

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/portfolio.png" width="300" />
  <img src="screenshots/alerts.png" width="300" />
</p>

---

## 🚀 Tech Stack
- Swift 5.9+  
- SwiftUI  
- SwiftData  
- Combine  
- URLSession  
- UserNotifications  

---

## 🔧 Installation
1. Clone the repo:
   ```bash
   git clone https://github.com/yourusername/CryptoPortfolioTracker.git
