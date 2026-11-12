package com.hilalsafi.cryptoclicker.core

// What the native game sends back, one class per view in
// android/swift/Sources/CryptoClickerBridge/Views.swift and Bridge.swift. Numbers and wording come
// formatted from Swift, so both apps show them identically; these classes only carry them.
// Optional Swift fields are nullable here, and every other field is required.

/** The answer to every request. */
data class Response(
    val ok: Boolean,
    val error: String?,
    val revision: Int?,
    val live: Live?,
    /** Present when the game changed since the revision the app sent. */
    val game: GameView?,
    val toasts: List<Toast>,
    val tap: TapResult?,
    val bought: Boolean?,
    val info: Info?,
) {
    companion object {
        fun parse(text: String): Response = from(Json.parseObject(text))

        fun from(o: JsonObject) = Response(
            ok = o.bool("ok"),
            error = o.stringOrNull("error"),
            revision = o.intOrNull("revision"),
            live = o.objOrNull("live")?.let(Live::from),
            game = o.objOrNull("game")?.let(GameView::from),
            toasts = o.list("toasts", Toast::from),
            tap = o.objOrNull("tap")?.let(TapResult::from),
            bought = o.boolOrNull("bought"),
            info = o.objOrNull("info")?.let(Info::from),
        )
    }
}

/** The balance and what changes it, five times a second. */
data class Live(
    val coins: Double,
    val balance: String,
    val balanceExact: String,
    val income: String,
    val incomeExact: String,
    val tap: String,
    val tapExact: String,
    val combo: Combo?,
    val bullRun: BullRun?,
) {
    companion object {
        fun from(o: JsonObject) = Live(
            coins = o.double("coins"),
            balance = o.string("balance"),
            balanceExact = o.string("balanceExact"),
            income = o.string("income"),
            incomeExact = o.string("incomeExact"),
            tap = o.string("tap"),
            tapExact = o.string("tapExact"),
            combo = o.objOrNull("combo")?.let(Combo::from),
            bullRun = o.objOrNull("bullRun")?.let(BullRun::from),
        )
    }
}

data class Combo(val title: String, val taps: String, val isMax: Boolean) {
    companion object {
        fun from(o: JsonObject) = Combo(o.string("title"), o.string("taps"), o.bool("isMax"))
    }
}

data class BullRun(val title: String, val multiplier: String, val remaining: String) {
    companion object {
        fun from(o: JsonObject) = BullRun(o.string("title"), o.string("multiplier"), o.string("remaining"))
    }
}

/** What one tap earned, for the "+value" floating up from the coin. */
data class TapResult(val earned: String, val earnedExact: String) {
    companion object {
        fun from(o: JsonObject) = TapResult(o.string("earned"), o.string("earnedExact"))
    }
}

data class Toast(val id: Int, val icon: String, val title: String, val message: String) {
    companion object {
        fun from(o: JsonObject) = Toast(o.int("id"), o.string("icon"), o.string("title"), o.string("message"))
    }
}

data class Info(val timeZone: String, val secondsFromGMT: Int, val saveVersion: Int, val debugTools: Boolean) {
    companion object {
        fun from(o: JsonObject) =
            Info(o.string("timeZone"), o.int("secondsFromGMT"), o.int("saveVersion"), o.bool("debugTools"))
    }
}

/** Everything but the live balance, sent when it changes. */
data class GameView(
    val shop: Shop,
    val welcomeBack: WelcomeBack?,
    val purchaseNote: PurchaseNote?,
    val unreadableSave: UnreadableSave?,
    val errorMessage: String?,
    val debugTools: Boolean,
) {
    companion object {
        fun from(o: JsonObject) = GameView(
            shop = Shop.from(o.obj("shop")),
            welcomeBack = o.objOrNull("welcomeBack")?.let(WelcomeBack::from),
            purchaseNote = o.objOrNull("purchaseNote")?.let(PurchaseNote::from),
            unreadableSave = o.objOrNull("unreadableSave")?.let(UnreadableSave::from),
            errorMessage = o.stringOrNull("errorMessage"),
            debugTools = o.bool("debugTools"),
        )
    }
}

// MARK: Shop

data class Shop(
    val minersDetail: String,
    val miners: List<Miner>,
    val lockedMiner: LockedMiner?,
    val offlineMining: OfflineMining,
    val powerUps: List<PowerUp>,
    val upgradesDetail: String?,
    val upgradesEmpty: String?,
    val upgrades: List<Upgrade>,
    val purchased: List<Upgrade>,
) {
    companion object {
        fun from(o: JsonObject) = Shop(
            minersDetail = o.string("minersDetail"),
            miners = o.list("miners", Miner::from),
            lockedMiner = o.objOrNull("lockedMiner")?.let(LockedMiner::from),
            offlineMining = OfflineMining.from(o.obj("offlineMining")),
            powerUps = o.list("powerUps", PowerUp::from),
            upgradesDetail = o.stringOrNull("upgradesDetail"),
            upgradesEmpty = o.stringOrNull("upgradesEmpty"),
            upgrades = o.list("upgrades", Upgrade::from),
            purchased = o.list("purchased", Upgrade::from),
        )
    }
}

data class Miner(
    val id: String,
    val emoji: String,
    val name: String,
    val owned: Int,
    val ownedText: String?,
    val line: String,
    val nextOne: String,
    val isBestValue: Boolean,
    val mk: String?,
    val legacy: String?,
    val milestone: ProgressLine?,
    val legacyProgress: ProgressLine?,
    /** ×1, ×10, ×100 and Max, in that order. */
    val buy: List<BuyOption>,
    val upgrade: MinerUpgrade?,
) {
    companion object {
        fun from(o: JsonObject) = Miner(
            id = o.string("id"),
            emoji = o.string("emoji"),
            name = o.string("name"),
            owned = o.int("owned"),
            ownedText = o.stringOrNull("ownedText"),
            line = o.string("line"),
            nextOne = o.string("nextOne"),
            isBestValue = o.bool("isBestValue"),
            mk = o.stringOrNull("mk"),
            legacy = o.stringOrNull("legacy"),
            milestone = o.objOrNull("milestone")?.let(ProgressLine::from),
            legacyProgress = o.objOrNull("legacyProgress")?.let(ProgressLine::from),
            buy = o.list("buy", BuyOption::from),
            upgrade = o.objOrNull("upgrade")?.let(MinerUpgrade::from),
        )
    }
}

data class ProgressLine(val fraction: Double, val text: String) {
    companion object {
        fun from(o: JsonObject) = ProgressLine(o.double("fraction"), o.string("text"))
    }
}

data class BuyOption(val count: Int, val label: String, val price: String, val canAfford: Boolean) {
    companion object {
        fun from(o: JsonObject) = BuyOption(o.int("count"), o.string("label"), o.string("price"), o.bool("canAfford"))
    }
}

data class MinerUpgrade(val name: String, val detail: String, val price: String, val canAfford: Boolean) {
    companion object {
        fun from(o: JsonObject) =
            MinerUpgrade(o.string("name"), o.string("detail"), o.string("price"), o.bool("canAfford"))
    }
}

data class LockedMiner(val needsPrestige: Boolean, val text: String) {
    companion object {
        fun from(o: JsonObject) = LockedMiner(o.bool("needsPrestige"), o.string("text"))
    }
}

data class OfflineMining(
    val subtitle: String,
    val price: String?,
    val canAfford: Boolean,
    val now: String,
    val next: String?,
) {
    companion object {
        fun from(o: JsonObject) = OfflineMining(
            subtitle = o.string("subtitle"),
            price = o.stringOrNull("price"),
            canAfford = o.bool("canAfford"),
            now = o.string("now"),
            next = o.stringOrNull("next"),
        )
    }
}

data class PowerUp(
    val id: String,
    val name: String,
    val symbol: String,
    val summary: String,
    val subtitle: String,
    val level: Int,
    val maxLevel: Int,
    val price: String?,
    val canAfford: Boolean,
    val valueName: String,
    val now: String,
    val next: String?,
    /** Set while it waits on another power-up. */
    val locked: String?,
) {
    companion object {
        fun from(o: JsonObject) = PowerUp(
            id = o.string("id"),
            name = o.string("name"),
            symbol = o.string("symbol"),
            summary = o.string("summary"),
            subtitle = o.string("subtitle"),
            level = o.int("level"),
            maxLevel = o.int("maxLevel"),
            price = o.stringOrNull("price"),
            canAfford = o.bool("canAfford"),
            valueName = o.string("valueName"),
            now = o.string("now"),
            next = o.stringOrNull("next"),
            locked = o.stringOrNull("locked"),
        )
    }
}

data class Upgrade(
    val id: String,
    val name: String,
    val summary: String,
    val symbol: String,
    /** tapping, production, steps or miniGames */
    val category: String,
    val price: String,
    val canAfford: Boolean,
) {
    companion object {
        fun from(o: JsonObject) = Upgrade(
            id = o.string("id"),
            name = o.string("name"),
            summary = o.string("summary"),
            symbol = o.string("symbol"),
            category = o.string("category"),
            price = o.string("price"),
            canAfford = o.bool("canAfford"),
        )
    }
}

// MARK: Popups

data class PurchaseNote(
    val id: Int,
    val stamp: Int,
    val title: String,
    val names: String,
    val more: String?,
    val perSecond: Gain?,
    val perTap: Gain?,
    val effects: String?,
    val remaining: Double,
    val lifetime: Double,
) {
    companion object {
        fun from(o: JsonObject) = PurchaseNote(
            id = o.int("id"),
            stamp = o.int("stamp"),
            title = o.string("title"),
            names = o.string("names"),
            more = o.stringOrNull("more"),
            perSecond = o.objOrNull("perSecond")?.let(Gain::from),
            perTap = o.objOrNull("perTap")?.let(Gain::from),
            effects = o.stringOrNull("effects"),
            remaining = o.double("remaining"),
            lifetime = o.double("lifetime"),
        )
    }
}

data class Gain(val added: String, val total: String) {
    companion object {
        fun from(o: JsonObject) = Gain(o.string("added"), o.string("total"))
    }
}

data class WelcomeBack(
    val id: Int,
    val away: String,
    val earned: String,
    val highlights: List<IconLine>,
    val suggestion: Suggestion?,
    val offlineNote: OfflineNote?,
    val time: List<TitledValue>,
    val sources: List<Source>,
    val total: String,
    val multipliers: List<TitledValue>,
    val multiplierTotal: String,
) {
    companion object {
        fun from(o: JsonObject) = WelcomeBack(
            id = o.int("id"),
            away = o.string("away"),
            earned = o.string("earned"),
            highlights = o.list("highlights", IconLine::from),
            suggestion = o.objOrNull("suggestion")?.let(Suggestion::from),
            offlineNote = o.objOrNull("offlineNote")?.let(OfflineNote::from),
            time = o.list("time", TitledValue::from),
            sources = o.list("sources", Source::from),
            total = o.string("total"),
            multipliers = o.list("multipliers", TitledValue::from),
            multiplierTotal = o.string("multiplierTotal"),
        )
    }
}

data class IconLine(val icon: String, val text: String) {
    companion object {
        fun from(o: JsonObject) = IconLine(o.string("icon"), o.string("text"))
    }
}

data class TitledValue(val title: String, val value: String) {
    companion object {
        fun from(o: JsonObject) = TitledValue(o.string("title"), o.string("value"))
    }
}

data class Suggestion(
    val name: String,
    val detail: String,
    val price: String,
    val canAfford: Boolean,
    val bought: Boolean,
) {
    companion object {
        fun from(o: JsonObject) =
            Suggestion(o.string("name"), o.string("detail"), o.string("price"), o.bool("canAfford"), o.bool("bought"))
    }
}

data class OfflineNote(val text: String, val button: String) {
    companion object {
        fun from(o: JsonObject) = OfflineNote(o.string("text"), o.string("button"))
    }
}

data class Source(
    /** A miner's emoji, or null for automatic taps. */
    val emoji: String?,
    val name: String,
    val detail: String,
    val coins: String,
    val share: String,
    val fraction: Double,
) {
    companion object {
        fun from(o: JsonObject) = Source(
            emoji = o.stringOrNull("emoji"),
            name = o.string("name"),
            detail = o.string("detail"),
            coins = o.string("coins"),
            share = o.string("share"),
            fraction = o.double("fraction"),
        )
    }
}

data class UnreadableSave(val title: String, val message: String) {
    companion object {
        fun from(o: JsonObject) = UnreadableSave(o.string("title"), o.string("message"))
    }
}
