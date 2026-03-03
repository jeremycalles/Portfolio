import Foundation
import SwiftUI

// MARK: - Supported Languages
public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }
}

// MARK: - Language Manager
public class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()
    
    private let languageKey = "app_language"
    
    /// A refresh ID that changes when language changes, forcing view updates
    @Published public var refreshID = UUID()
    
    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            // Update the bundle
            _currentBundle = nil
            // Force complete UI refresh
            refreshID = UUID()
        }
    }
    
    private var _currentBundle: Bundle?
    
    public var bundle: Bundle {
        if let bundle = _currentBundle {
            return bundle
        }
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            _currentBundle = bundle
            return bundle
        }
        return Bundle.main
    }
    
    private init() {
        // Check if user has previously set a language
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // First launch: detect device locale
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            
            if deviceLanguage == "fr" {
                self.currentLanguage = .french
            } else {
                // Default to English for any other language
                self.currentLanguage = .english
            }
            
            // Save the initial choice
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }
    
    /// Get localized string for the current language
    func localized(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

// MARK: - Localization Helper using LanguageManager
struct L10n {
    private static var manager: LanguageManager { LanguageManager.shared }
    
    // General
    public static var appName: String { manager.localized("app.name") }
    public static var appTagline: String { manager.localized("app.tagline") }
    public static var generalComparisonPeriod: String { manager.localized("general.comparisonPeriod") }
    public static var generalCancel: String { manager.localized("general.cancel") }
    public static var generalSave: String { manager.localized("general.save") }
    public static var generalDelete: String { manager.localized("general.delete") }
    public static var generalEdit: String { manager.localized("general.edit") }
    public static var generalAdd: String { manager.localized("general.add") }
    public static var generalDone: String { manager.localized("general.done") }
    public static var generalOk: String { manager.localized("general.ok") }
    public static var generalError: String { manager.localized("general.error") }
    public static var generalLoading: String { manager.localized("general.loading") }
    public static var generalNoData: String { manager.localized("general.noData") }
    public static var generalOverview: String { manager.localized("general.overview") }
    public static var generalManage: String { manager.localized("general.manage") }
    public static var generalData: String { manager.localized("general.data") }
    public static var generalTotal: String { manager.localized("general.total") }
    public static var generalSubtotal: String { manager.localized("general.subtotal") }
    public static var generalGrandTotal: String { manager.localized("general.grandTotal") }
    public static var generalPerformance: String { manager.localized("general.performance") }
    public static var generalNa: String { manager.localized("general.na") }
    public static var generalBuild: String { manager.localized("general.build") }
    
    // Navigation
    public static var navDashboard: String { manager.localized("nav.dashboard") }
    public static var navInstruments: String { manager.localized("nav.instruments") }
    public static var navAccounts: String { manager.localized("nav.accounts") }
    public static var navReports: String { manager.localized("nav.reports") }
    public static var navSettings: String { manager.localized("nav.settings") }
    public static var navQuadrantReport: String { manager.localized("nav.quadrantReport") }
    public static var navAllHoldings: String { manager.localized("nav.allHoldings") }
    public static var navQuadrants: String { manager.localized("nav.quadrants") }
    public static var navBankAccounts: String { manager.localized("nav.bankAccounts") }
    public static var navHoldings: String { manager.localized("nav.holdings") }
    public static var navPriceHistory: String { manager.localized("nav.priceHistory") }
    public static var navPriceGraph: String { manager.localized("nav.priceGraph") }
    
    // Periods
    public static var period1Day: String { manager.localized("period.1day") }
    public static var period1Week: String { manager.localized("period.1week") }
    public static var period1Month: String { manager.localized("period.1month") }
    public static var period1Year: String { manager.localized("period.1year") }
    public static var periodYearToDate: String { manager.localized("period.yearToDate") }
    
    // Dashboard
    public static var dashboardPortfolioSummary: String { manager.localized("dashboard.portfolioSummary") }
    public static var dashboardPortfolioTrend: String { manager.localized("dashboard.portfolioTrend") }
    public static var dashboardPortfolioValue: String { manager.localized("dashboard.portfolioValue") }
    public static var dashboardPortfolioValueGold: String { manager.localized("dashboard.portfolioValueGold") }
    public static var dashboardQuadrantAllocation: String { manager.localized("dashboard.quadrantAllocation") }
    public static var dashboardAccountAllocation: String { manager.localized("dashboard.accountAllocation") }
    public static var dashboardNoHoldings: String { manager.localized("dashboard.noHoldings") }
    public static var dashboardNoHistoricalData: String { manager.localized("dashboard.noHistoricalData") }
    public static var dashboardComparisonPeriod: String { manager.localized("dashboard.comparisonPeriod") }
    public static var dashboardViewMode: String { manager.localized("dashboard.viewMode") }
    public static var dashboardQuadrants: String { manager.localized("dashboard.quadrants") }
    public static var dashboardHoldings: String { manager.localized("dashboard.holdings") }
    public static var dashboardAccounts: String { manager.localized("dashboard.accounts") }
    public static var dashboardTotalPortfolioValue: String { manager.localized("dashboard.totalPortfolioValue") }
    public static var dashboardNoAccountsWithData: String { manager.localized("dashboard.noAccountsWithData") }
    public static var dashboardNoDataAvailable: String { manager.localized("dashboard.noDataAvailable") }
    
    // Portfolio Summary
    public static var summaryGold: String { manager.localized("summary.gold") }
    public static var summaryFrom: String { manager.localized("summary.from") }
    public static var summaryOz: String { manager.localized("summary.oz") }
    public static var summaryTotalEur: String { manager.localized("summary.totalEur") }
    public static var summaryLastUpdate: String { manager.localized("summary.lastUpdate") }
    
    // Instruments
    public static var instrumentsTitle: String { manager.localized("instruments.title") }
    public static var instrumentsQuadrants: String { manager.localized("instruments.quadrants") }
    public static var instrumentsUnassigned: String { manager.localized("instruments.unassigned") }
    public static var instrumentsAddInstrument: String { manager.localized("instruments.addInstrument") }
    public static var instrumentsEditInstrument: String { manager.localized("instruments.editInstrument") }
    public static var instrumentsIsinHint: String { manager.localized("instruments.isinHint") }
    public static var instrumentsRemoveFromQuadrant: String { manager.localized("instruments.removeFromQuadrant") }
    public static var instrumentsAssignToQuadrant: String { manager.localized("instruments.assignToQuadrant") }
    public static var instrumentsDeleteInstrument: String { manager.localized("instruments.deleteInstrument") }
    public static var instrumentsNoQuadrantsAvailable: String { manager.localized("instruments.noQuadrantsAvailable") }
    public static var instrumentsPriceDetails: String { manager.localized("instruments.priceDetails") }
    public static var instrumentsCurrentPrice: String { manager.localized("instruments.currentPrice") }
    public static var instrumentsCurrency: String { manager.localized("instruments.currency") }
    public static func instrumentsCount(_ count: Int) -> String {
        String(format: manager.localized("instruments.count"), count)
    }
    
    // Accounts
    public static var accountsTitle: String { manager.localized("accounts.title") }
    public static var accountsAddAccount: String { manager.localized("accounts.addAccount") }
    public static var accountsNoAccounts: String { manager.localized("accounts.noAccounts") }
    public static var accountsOtherAccounts: String { manager.localized("accounts.otherAccounts") }
    public static var accountsNoBankAccounts: String { manager.localized("accounts.noBankAccounts") }
    public static var accountsAddBankAccountFirst: String { manager.localized("accounts.addBankAccountFirst") }
    public static var accountsSelectAccount: String { manager.localized("accounts.selectAccount") }
    public static var accountsSelectAnAccount: String { manager.localized("accounts.selectAnAccount") }
    public static var accountsNoHoldingsInAccount: String { manager.localized("accounts.noHoldingsInAccount") }
    public static var accountsNoHoldingsYet: String { manager.localized("accounts.noHoldingsYet") }
    public static var accountsTapToAddHolding: String { manager.localized("accounts.tapToAddHolding") }
    public static var accountsAcrossAllAccounts: String { manager.localized("accounts.acrossAllAccounts") }
    public static func accountsHoldingsCount(_ count: Int) -> String {
        String(format: manager.localized("accounts.holdingsCount"), count)
    }
    public static func accountsBankAccountsCount(_ count: Int) -> String {
        String(format: manager.localized("accounts.bankAccountsCount"), count)
    }
    public static func accountsHoldingsCountTitle(_ count: Int) -> String {
        String(format: manager.localized("accounts.holdingsCountTitle"), count)
    }
    
    // Holdings
    public static var holdingsAddHolding: String { manager.localized("holdings.addHolding") }
    public static var holdingsEditHolding: String { manager.localized("holdings.editHolding") }
    public static var holdingsSelectInstrument: String { manager.localized("holdings.selectInstrument") }
    public static var holdingsSelectAnInstrument: String { manager.localized("holdings.selectAnInstrument") }
    public static var holdingsSelectAnInstrumentGraph: String { manager.localized("holdings.selectAnInstrumentGraph") }
    public static var holdingsPurchaseDetails: String { manager.localized("holdings.purchaseDetails") }
    public static var holdingsPurchaseDetailsHint: String { manager.localized("holdings.purchaseDetailsHint") }
    public static var holdingsInstrument: String { manager.localized("holdings.instrument") }
    public static var holdingsValue: String { manager.localized("holdings.value") }
    public static var holdingsChange: String { manager.localized("holdings.change") }
    public static var holdingsQty: String { manager.localized("holdings.qty") }
    public static var holdingsNoHoldings: String { manager.localized("holdings.noHoldings") }
    public static var holdingsNoChartData: String { manager.localized("holdings.noChartData") }
    
    // Quadrants
    public static var quadrantsAddQuadrant: String { manager.localized("quadrants.addQuadrant") }
    public static var quadrantsQuadrantDetails: String { manager.localized("quadrants.quadrantDetails") }
    public static var quadrantsQuadrantDetailsHint: String { manager.localized("quadrants.quadrantDetailsHint") }
    public static var quadrantsQuadrantAssignment: String { manager.localized("quadrants.quadrantAssignment") }
    public static var quadrantsQuadrantAssignmentHint: String { manager.localized("quadrants.quadrantAssignmentHint") }
    public static var quadrantsCategorizeHint: String { manager.localized("quadrants.categorizeHint") }
    public static func quadrantsCount(_ count: Int) -> String {
        String(format: manager.localized("quadrants.quadrantsCount"), count)
    }
    
    // Reports
    public static var reportsDate: String { manager.localized("reports.date") }
    public static var reportsQuadrantReport: String { manager.localized("reports.quadrantReport") }
    public static var reportsComparisonPeriod: String { manager.localized("reports.comparisonPeriod") }
    public static var reportsNoHoldingsToDisplay: String { manager.localized("reports.noHoldingsToDisplay") }
    public static var reportsAddInstrumentsHint: String { manager.localized("reports.addInstrumentsHint") }
    public static var reportsNoPriceHistoryAvailable: String { manager.localized("reports.noPriceHistoryAvailable") }
    public static var reportsClickToAddPrice: String { manager.localized("reports.clickToAddPrice") }
    public static var reportsNoPriceDataForPeriod: String { manager.localized("reports.noPriceDataForPeriod") }
    public static func reportsVs(_ date: String) -> String {
        String(format: manager.localized("reports.vs"), date)
    }
    public static func reportsAsOf(_ date: String) -> String {
        String(format: manager.localized("reports.asOf"), date)
    }
    public static func reportsDeleteConfirmation(_ date: String) -> String {
        String(format: manager.localized("reports.deleteConfirmation"), date)
    }
    
    // Stats
    public static var statsBestPerformer: String { manager.localized("stats.bestPerformer") }
    public static var statsWorstPerformer: String { manager.localized("stats.worstPerformer") }
    public static var statsLargestPosition: String { manager.localized("stats.largestPosition") }
    public static var statsTotalHoldings: String { manager.localized("stats.totalHoldings") }
    // Settings
    public static var settingsTitle: String { manager.localized("settings.title") }
    public static var settingsDemoMode: String { manager.localized("settings.demoMode") }
    public static var settingsDemoModeDescription: String { manager.localized("settings.demoModeDescription") }
    public static var settingsDemoModeEnable: String { manager.localized("settings.demoModeEnable") }
    public static var settingsDemoModeActive: String { manager.localized("settings.demoModeActive") }
    public static var settingsDemoModeRandomize: String { manager.localized("settings.demoModeRandomize") }
    public static var settingsLanguage: String { manager.localized("settings.language") }
    public static var settingsLanguageDescription: String { manager.localized("settings.languageDescription") }
    public static var settingsEnglish: String { manager.localized("settings.english") }
    public static var settingsFrench: String { manager.localized("settings.french") }
    public static var settingsDataManagement: String { manager.localized("settings.dataManagement") }
    public static var settingsUpdatePrices: String { manager.localized("settings.updatePrices") }
    public static var settingsBackfillData: String { manager.localized("settings.backfillData") }
    public static var settingsAbout: String { manager.localized("settings.about") }
    public static var settingsVersion: String { manager.localized("settings.version") }
    public static var settingsGeneral: String { manager.localized("settings.general") }
    public static var settingsDatabase: String { manager.localized("settings.database") }
    public static var settingsBackground: String { manager.localized("settings.background") }
    public static var settingsImportExportHint: String { manager.localized("settings.importExportHint") }
    public static var settingsImportDatabase: String { manager.localized("settings.importDatabase") }
    public static var settingsExportDatabase: String { manager.localized("settings.exportDatabase") }
    public static var settingsDatabaseImportExport: String { manager.localized("settings.databaseImportExport") }
    public static var settingsOpenInFinder: String { manager.localized("settings.openInFinder") }
    public static var settingsPrivacyMode: String { manager.localized("settings.privacyMode") }
    public static var settingsBackgroundRefresh: String { manager.localized("settings.backgroundRefresh") }
    public static var settingsBackgroundRefreshInterval: String { manager.localized("settings.backgroundRefreshInterval") }
    public static var settingsLastRefresh: String { manager.localized("settings.lastRefresh") }
    public static var settingsBackgroundUpdates: String { manager.localized("settings.backgroundUpdates") }
    public static var settingsBackgroundUpdatesDescription: String { manager.localized("settings.backgroundUpdatesDescription") }
    public static var settingsAutomaticUpdates: String { manager.localized("settings.automaticUpdates") }
    public static var settingsAutomaticUpdatesDescription: String { manager.localized("settings.automaticUpdatesDescription") }
    public static var settingsStatusActive: String { manager.localized("settings.statusActive") }
    public static var settingsStatusInstalledNotRunning: String { manager.localized("settings.statusInstalledNotRunning") }
    public static var settingsStatusNotInstalled: String { manager.localized("settings.statusNotInstalled") }
    public static var settingsEnable: String { manager.localized("settings.enable") }
    public static var settingsDisable: String { manager.localized("settings.disable") }
    public static var settingsRunNow: String { manager.localized("settings.runNow") }
    public static var settingsRefreshStatus: String { manager.localized("settings.refreshStatus") }
    public static var settingsRecentActivity: String { manager.localized("settings.recentActivity") }
    public static var settingsOpenLogsFolder: String { manager.localized("settings.openLogsFolder") }
    public static var settingsNoLogsAvailable: String { manager.localized("settings.noLogsAvailable") }
    public static var settingsLogsDescription: String { manager.localized("settings.logsDescription") }
    public static var settingsBackgroundRefreshLogs: String { manager.localized("settings.backgroundRefreshLogs") }
    public static var settingsAccountDetails: String { manager.localized("settings.accountDetails") }
    public static var settingsAccountDetailsHint: String { manager.localized("settings.accountDetailsHint") }
    public static var settingsUpdatePricesDescription: String { manager.localized("settings.updatePricesDescription") }
    public static var settingsStorageLogs: String { manager.localized("settings.storageLogs") }
    public static var settingsStorageLogsDescription: String { manager.localized("settings.storageLogsDescription") }
    public static var settingsDatabaseStoredLocally: String { manager.localized("settings.databaseStoredLocally") }
    public static var settingsBackupToICloudNow: String { manager.localized("settings.backupToICloudNow") }
    
    // Actions
    public static var actionUpdatePrices: String { manager.localized("action.updatePrices") }
    public static var actionUpdateAllPrices: String { manager.localized("action.updateAllPrices") }
    public static var actionBackfill1Year: String { manager.localized("action.backfill1Year") }
    public static var actionBackfill2Years: String { manager.localized("action.backfill2Years") }
    public static var actionBackfill5Years: String { manager.localized("action.backfill5Years") }
    public static var actionBackfill1Month: String { manager.localized("action.backfill1Month") }
    public static var actionBackfillHistorical1Year: String { manager.localized("action.backfillHistorical1Year") }
    public static var actionBackfillHistorical2Years: String { manager.localized("action.backfillHistorical2Years") }
    public static var actionBackfillHistorical5Years: String { manager.localized("action.backfillHistorical5Years") }
    public static var actionAddPrice: String { manager.localized("action.addPrice") }
    public static var actionEditPrice: String { manager.localized("action.editPrice") }
    
    // Chart
    public static var chartNoGoldPriceData: String { manager.localized("chart.noGoldPriceData") }
    public static var chartClickToToggle: String { manager.localized("chart.clickToToggle") }
    public static var chartNoPriceHistory: String { manager.localized("chart.noPriceHistory") }
    public static var chartPortfolioLabel: String { manager.localized("chart.portfolioLabel") }
    public static var chartSp500Comparison: String { manager.localized("chart.sp500Comparison") }
    public static var chartGoldComparison: String { manager.localized("chart.goldComparison") }
    public static var chartMsciWorldComparison: String { manager.localized("chart.msciWorldComparison") }
    // Privacy
    public static var privacyHidden: String { manager.localized("privacy.hidden") }
    public static var privacyHiddenLong: String { manager.localized("privacy.hiddenLong") }
    public static var privacyHiddenStars: String { manager.localized("privacy.hiddenStars") }
    
    // Tooltips
    public static var tooltipUpdateAllPrices: String { manager.localized("tooltip.updateAllPrices") }
    public static var tooltipBackfillHistoricalData: String { manager.localized("tooltip.backfillHistoricalData") }
    public static var tooltipAddPrice: String { manager.localized("tooltip.addPrice") }
    public static var tooltipEdit: String { manager.localized("tooltip.edit") }
    public static var tooltipDelete: String { manager.localized("tooltip.delete") }
    
    // Refresh Result
    public static var refreshSuccess: String { manager.localized("refresh.success") }
    public static var refreshPartial: String { manager.localized("refresh.partial") }
    public static var refreshFailed: String { manager.localized("refresh.failed") }
    public static var refreshFailedInstruments: String { manager.localized("refresh.failedInstruments") }
    public static var refreshDebugReasons: String { manager.localized("refresh.debugReasons") }
    public static func refreshSuccessDetail(_ count: Int) -> String {
        String(format: manager.localized("refresh.successDetail"), count)
    }
    public static func refreshResultDetail(_ success: Int, _ total: Int) -> String {
        String(format: manager.localized("refresh.resultDetail"), success, total)
    }
    
    // Lock (macOS)
    public static var lockUnlockButton: String { manager.localized("lock.unlockButton") }
    public static var lockReason: String { manager.localized("lock.reason") }
    public static var lockUnavailable: String { manager.localized("lock.unavailable") }
    public static var settingsTouchIDProtection: String { manager.localized("settings.touchIDProtection") }
    public static var settingsTouchIDProtectionDescription: String { manager.localized("settings.touchIDProtectionDescription") }
    public static var settingsTouchIDProtectionEnable: String { manager.localized("settings.touchIDProtectionEnable") }
    
    // Errors
    public static var errorFetchFailed: String { manager.localized("error.fetchFailed") }
    public static var errorSaveFailed: String { manager.localized("error.saveFailed") }
    public static var errorDeleteFailed: String { manager.localized("error.deleteFailed") }
}
