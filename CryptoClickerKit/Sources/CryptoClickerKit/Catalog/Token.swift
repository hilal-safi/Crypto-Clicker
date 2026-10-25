import Foundation

/// Crypto tokens bought on the Coin Exchange and used as Blackjack chips.
/// Prices span the whole game (100x per tier), so stakes can keep pace with income.
public enum TokenID: String, CaseIterable, Codable, Sendable, Identifiable {
    case shibaInu, dogecoin, xrp, cardano, solana, ethereum, bitcoin

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .shibaInu: "Shiba Inu"
        case .dogecoin: "Dogecoin"
        case .xrp: "XRP"
        case .cardano: "Cardano"
        case .solana: "Solana"
        case .ethereum: "Ethereum"
        case .bitcoin: "Bitcoin"
        }
    }

    public var ticker: String {
        switch self {
        case .shibaInu: "SHIB"
        case .dogecoin: "DOGE"
        case .xrp: "XRP"
        case .cardano: "ADA"
        case .solana: "SOL"
        case .ethereum: "ETH"
        case .bitcoin: "BTC"
        }
    }

    /// Asset catalog image name.
    public var imageName: String {
        switch self {
        case .shibaInu: "shibainu_image"
        case .dogecoin: "dogecoin_image"
        case .xrp: "xrp_image"
        case .cardano: "cardano_image"
        case .solana: "solana_image"
        case .ethereum: "ethereum_image"
        case .bitcoin: "bitcoin_image"
        }
    }

    /// Price of one token in coins.
    public var price: Double {
        switch self {
        case .shibaInu: 1_000
        case .dogecoin: 100_000
        case .xrp: 10_000_000
        case .cardano: 1_000_000_000
        case .solana: 100_000_000_000
        case .ethereum: 10_000_000_000_000
        case .bitcoin: 1_000_000_000_000_000
        }
    }
}
