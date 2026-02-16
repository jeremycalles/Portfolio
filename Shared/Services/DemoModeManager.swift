import Foundation
import SwiftUI

// MARK: - Demo Mode Manager
/// Manages demo mode settings with randomized quantities for portfolio anonymization
class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()
    
    private let demoModeKey = "demoModeEnabled"
    private let demoSeedKey = "demoModeSeed"
    
    /// Maximum value per instrument in demo mode (in the instrument's currency)
    private let maxValuePerInstrument: Double = 10_000.0
    /// Minimum value per instrument to ensure visible positions
    private let minValuePerInstrument: Double = 1_000.0
    
    @Published var isDemoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDemoModeEnabled, forKey: demoModeKey)
            if isDemoModeEnabled && demoSeed == 0 {
                // Generate a new seed when first enabling demo mode
                regenerateSeed()
            }
        }
    }
    
    @Published var demoSeed: UInt64 {
        didSet {
            UserDefaults.standard.set(Int64(bitPattern: demoSeed), forKey: demoSeedKey)
        }
    }
    
    // Cache of randomized quantities keyed by ISIN
    private var cachedQuantities: [String: Double] = [:]
    private var lastSeed: UInt64 = 0
    
    private init() {
        self.isDemoModeEnabled = UserDefaults.standard.bool(forKey: demoModeKey)
        let savedSeed = UserDefaults.standard.integer(forKey: demoSeedKey)
        self.demoSeed = savedSeed != 0 ? UInt64(bitPattern: Int64(savedSeed)) : 0
    }
    
    /// Regenerates the random seed and clears cached quantities
    func regenerateSeed() {
        demoSeed = UInt64.random(in: 1...UInt64.max)
        cachedQuantities.removeAll()
    }
    
    /// Gets a randomized quantity for a given ISIN based on price
    /// The quantity is calculated to ensure total value stays below 50,000
    /// - Parameters:
    ///   - isin: The instrument ISIN
    ///   - originalQuantity: The original quantity (used to check if holding exists)
    ///   - currentPrice: The current price per unit (required to calculate max quantity)
    /// - Returns: A randomized quantity that keeps total value under 50,000
    func getRandomizedQuantity(forIsin isin: String, originalQuantity: Double, currentPrice: Double?) -> Double {
        guard isDemoModeEnabled, originalQuantity > 0 else { return originalQuantity }
        
        // Check if seed changed, clear cache if so
        if lastSeed != demoSeed {
            cachedQuantities.removeAll()
            lastSeed = demoSeed
        }
        
        // Return cached value if available
        if let cached = cachedQuantities[isin] {
            return cached
        }
        
        // Generate a deterministic random factor based on seed and ISIN (0.0 to 1.0)
        var hasher = Hasher()
        hasher.combine(demoSeed)
        hasher.combine(isin)
        let hash = hasher.finalize()
        let randomFactor = abs(Double(hash)) / Double(Int.max)
        
        // Calculate quantity based on price to keep value under maxValuePerInstrument
        let randomQuantity: Double
        if let price = currentPrice, price > 0 {
            // Calculate max quantity that keeps value under limit
            let maxQuantity = maxValuePerInstrument / price
            let minQuantity = minValuePerInstrument / price
            
            // Random value between minQuantity and maxQuantity
            randomQuantity = minQuantity + randomFactor * (maxQuantity - minQuantity)
        } else {
            // Fallback if no price available: use a small fixed range
            randomQuantity = 10.0 + randomFactor * 90.0  // Range: 10 to 100
        }
        
        // Round to 2 decimal places for cleaner display
        let roundedQuantity = (randomQuantity * 100).rounded() / 100
        
        cachedQuantities[isin] = roundedQuantity
        return roundedQuantity
    }
    
    /// Gets the total randomized quantity for an ISIN across all accounts
    func getTotalRandomizedQuantity(forIsin isin: String, originalTotal: Double, currentPrice: Double?) -> Double {
        return getRandomizedQuantity(forIsin: isin, originalQuantity: originalTotal, currentPrice: currentPrice)
    }
}
