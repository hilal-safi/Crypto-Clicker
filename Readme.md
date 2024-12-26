# Crypto Clicker

**Crypto Clicker** is a SwiftUI-based game inspired by Cookie Clicker, where users mine cryptocurrency, purchase items to improve mining efficiency, and unlock achievements. The app combines engaging gameplay mechanics with a clean, intuitive design and encourages incremental progress through mining, upgrades, and mini-games like blackjack.

**Note:** The game is still in progress and not yet complete. Future features and improvements are planned, as outlined below.

---

## Features

### Core Gameplay
- **Coin Mining:** Tap the central coin to mine cryptocurrency and accumulate wealth.
- **Store Items:** Purchase upgrades like Chromebooks, Desktops, Servers, and Mining Centers, which passively increase coin production.
- **Power-Ups:** Unlock and level up power-ups that provide significant boosts to mining efficiency.

### Achievements
- **Milestone Tracking:** Earn achievements for milestones such as mining coins, earning coins per second, and increasing coins per click.
- **Tiered Progression:** Each achievement has three tiers, offering progressively more challenging goals.

### Mini-Games
- **Blackjack:** A fun mini-game where you can wager in-game currencies like Dogecoin, Ethereum, and Solana to multiply your earnings.

### Customization
- **Themes:** Choose from light mode, dark mode, or auto mode to match your device settings.
- **Sound Effects:** Enable or disable game sounds, including chime effects.

---

## Code Structure

The project adheres to the **Model-View-ViewModel (MVVM)** design pattern to ensure a clean separation of concerns, maintainability, and scalability.

### Folder Organization
- **Views Folder:** Contains all the UI components and front-end elements.
- **Models Folder:** Manages the backend logic, including data structures, business logic, and state management.
- **Resources Folder:** Stores app assets like images and sounds.
- **Utilities Folder:** Houses shared helper functions and extensions.

### Key Files and Their Roles

#### **Views Folder**
- **`ContentView.swift`:**
  - Displays the main gameplay interface, including the coin value and shop button.
  - Focused solely on the coin's display and user interactions with the shop.

- **`BackgroundView.swift`:**
  - Provides a consistent background design across all app screens.
  - Simplifies UI styling by centralizing background logic.

- **`CoinView.swift`:**
  - Handles the central coin button UI and interactions.
  - Calls backend logic for incrementing coin values, managed in the models.

- **`ShopView.swift`:**
  - Displays purchasable store items (e.g., Chromebook, Desktop, Server, Mine Center) in a 2x2 grid layout.
  - Contains buttons to increase or decrease item quantities.

- **`AchievementsView.swift`:**
  - Displays a list of achievements, categorized into mining milestones, coins per second, and coins per click.
  - Uses `AchievementsItemView.swift` to render each achievement.

- **`MiniGamesView.swift`:**
  - Manages the mini-game interface, currently featuring a blackjack game.

#### **Models Folder**
- **`CryptoCoin.swift`:**
  - Defines the core structure of the cryptocurrency, including its value and associated logic.
  - Tracks coin production rates and interactions with store items.

- **`CryptoStore.swift`:**
  - Manages store inventory and handles the logic for purchasing items and updating quantities.
  - Tracks passive coin production rates contributed by store items.

- **`PowerUps.swift`:**
  - Tracks purchased power-ups and their levels.
  - Implements logic for boosting mining efficiency.

- **`AchievementsModel.swift`:**
  - Centralizes achievement data in a single array for easy management.
  - Tracks progress toward milestones and determines tier completion.

- **`PowerUpInfo.swift`:**
  - Struct for managing individual power-up properties, including names, effects, and levels.

- **`AchievementsItemView.swift`:**
  - Handles the display and layout of individual achievement items.

#### **Utilities Folder**
- **`AVPlayer+Ding.swift`:**
  - Extension to manage chime sound functionality when specific actions occur.

- **`coinsBinding.swift`:**
  - A helper binding property for handling optional coin values efficiently.

---

## Gameplay Progression

1. **Start Mining:** Tap the central coin to mine your first cryptocurrency.
2. **Upgrade Efficiency:** Spend mined coins in the store to buy items that increase passive production.
3. **Power-Up:** Unlock and level up power-ups for exponential growth.
4. **Compete and Achieve:** Track your progress with achievements and milestones.
5. **Mini-Games:** Test your luck in blackjack and other planned games for added excitement.

---

## Installation and Setup

1. Clone the repository:
   ```git clone https://github.com/hilal-safi/crypto-clicker.git```

1. Clone the repository:
    ```cd crypto-clicker```
    ```open Crypto_Clicker.xcodeproj```

3. Build and run the app on your preferred iOS simulator or device:
   - In Xcode, select your target device or simulator.
   - Click the **Run** button (▶️) in the toolbar or press `Cmd + R` to build and launch the app.

---

## Future Enhancements

- **Additional Mini-Games:** Introduce more engaging activities for players.
- **Thematic Customizations:** Offer themes, coin designs, and personalized backgrounds.
- **Dynamic Events:** Incorporate time-limited challenges for extra rewards.
- **Bug Fixes and Optimizations:** Continue refining the app for better performance and user experience.

---

## Contributing

Contributions are welcome! If you'd like to contribute:
1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Commit your changes and submit a pull request.

---

**Enjoy mining, upgrading, and achieving greatness in Crypto Clicker! 🚀**
