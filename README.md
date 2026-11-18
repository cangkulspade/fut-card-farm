# ⚽ FUT Card Farm

A foundational gameplay prototype for a football card-collecting tycoon experience on **Roblox**, built with **Luau**.

> **Repository Scope:** This public repository contains core architectural scripts and early-stage mechanics for documentation purposes. The complete production build, full asset library, and extended game systems are maintained in a private repository.

### Core Architecture
* **Gacha System (`GachaManager`):** Conveyor-based card rolling mechanics with physical interaction triggers and rarity probability handling.
* **Base & Progression (`HouseIncomeManager`):** Pedestal slot management featuring passive income generation and card level upgrades.
* **Economy & Persistence (`CurrencyManager`):** Player currency management (`leaderstats`) and automated session saving via `DataStoreService`.
* **Client Interface (`TycoonHUD`):** Real-time player statistics and progression display.
