import Foundation

/// Crypto tokens bought in the Shop's Tokens page and bet at the casino games, cheapest first.
/// Prices span the whole game (100x per tier for the original seven, with Tether, BNB and Monero in
/// between, and SafeMoon below them all at 100 coins), so stakes can keep pace with income. Tether
/// is a stablecoin: its price barely moves. SafeMoon swings most.
///
/// Market prices and news are seeded by each token's name, not its place in this list, so adding a
/// token leaves the others' prices and history as they were.
public enum TokenID: String, CaseIterable, Codable, Sendable, Identifiable {
    case safeMoon, shibaInu, tether, dogecoin, xrp, bnb, monero, cardano, solana, ethereum, bitcoin

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .safeMoon: "SafeMoon"
        case .shibaInu: localized("Shiba Inu")
        case .tether: localized("Tether")
        case .dogecoin: localized("Dogecoin")
        case .xrp: "XRP"
        case .bnb: "BNB"
        case .monero: localized("Monero")
        case .cardano: localized("Cardano")
        case .solana: localized("Solana")
        case .ethereum: localized("Ethereum")
        case .bitcoin: localized("Bitcoin")
        }
    }

    public var ticker: String {
        switch self {
        case .safeMoon: "SFM"
        case .shibaInu: "SHIB"
        case .tether: "USDT"
        case .dogecoin: "DOGE"
        case .xrp: "XRP"
        case .bnb: "BNB"
        case .monero: "XMR"
        case .cardano: "ADA"
        case .solana: "SOL"
        case .ethereum: "ETH"
        case .bitcoin: "BTC"
        }
    }

    /// Asset catalog image name.
    public var imageName: String {
        switch self {
        case .safeMoon: "safemoon_image"
        case .shibaInu: "shibainu_image"
        case .tether: "tether_image"
        case .dogecoin: "dogecoin_image"
        case .xrp: "xrp_image"
        case .bnb: "bnb_image"
        case .monero: "monero_image"
        case .cardano: "cardano_image"
        case .solana: "solana_image"
        case .ethereum: "ethereum_image"
        case .bitcoin: "bitcoin_image"
        }
    }

    /// Price of one token in coins.
    public var price: Double {
        switch self {
        case .safeMoon: 100
        case .shibaInu: 1_000
        case .tether: 10_000
        case .dogecoin: 100_000
        case .xrp: 10_000_000
        case .bnb: 50_000_000
        case .monero: 200_000_000
        case .cardano: 1_000_000_000
        case .solana: 100_000_000_000
        case .ethereum: 10_000_000_000_000
        case .bitcoin: 1_000_000_000_000_000
        }
    }
}
