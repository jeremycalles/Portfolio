import Foundation
import SwiftUI

// MARK: - Supported Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }
}

// MARK: - Language Manager
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "app_language"
    
    /// A refresh ID that changes when language changes, forcing view updates
    @Published var refreshID = UUID()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            // Update the bundle
            _currentBundle = nil
            // Force complete UI refresh
            refreshID = UUID()
        }
    }
    
    private var _currentBundle: Bundle?
    
    var bundle: Bundle {
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
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}

// MARK: - Localization Helper using LanguageManager
struct L10n {
    private static var manager: LanguageManager { LanguageManager.shared }
    
    // General
    static var appName: String { manager.localized("app.name") }
    static var appTagline: String { manager.localized("app.tagline") }
    static var generalComparisonPeriod: String { manager.localized("general.comparisonPeriod") }
    static var generalCancel: String { manager.localized("general.cancel") }
    static var generalSave: String { manager.localized("general.save") }
    static var generalDelete: String { manager.localized("general.delete") }
    static var generalEdit: String { manager.localized("general.edit") }
    static var generalAdd: String { manager.localized("general.add") }
    static var generalDone: String { manager.localized("general.done") }
    static var generalOk: String { manager.localized("general.ok") }
    static var generalError: String { manager.localized("general.error") }
    static var generalLoading: String { manager.localized("general.loading") }
    static var generalNoData: String { manager.localized("general.noData") }
    static var generalOverview: String { manager.localized("general.overview") }
    static var generalManage: String { manager.localized("general.manage") }
    static var generalData: String { manager.localized("general.data") }
    static var generalTotal: String { manager.localized("general.total") }
    static var generalSubtotal: String { manager.localized("general.subtotal") }
    static var generalGrandTotal: String { manager.localized("general.grandTotal") }
    static var generalPerformance: String { manager.localized("general.performance") }
    static var generalNa: String { manager.localized("general.na") }
    static var generalBuild: String { manager.localized("general.build") }
    
    // Navigation
    static var navDashboard: String { manager.localized("nav.dashboard") }
    static var navInstruments: String { manager.localized("nav.instruments") }
    static var navAccounts: String { manager.localized("nav.accounts") }
    static var navReports: String { manager.localized("nav.reports") }
    static var navSettings: String { manager.localized("nav.settings") }
    static var navQuadrantReport: String { manager.localized("nav.quadrantReport") }
    static var navAllHoldings: String { manager.localized("nav.allHoldings") }
    static var navQuadrants: String { manager.localized("nav.quadrants") }
    static var navBankAccounts: String { manager.localized("nav.bankAccounts") }
    static var navHoldings: String { manager.localized("nav.holdings") }
    static var navPriceHistory: String { manager.localized("nav.priceHistory") }
    static var navPriceGraph: String { manager.localized("nav.priceGraph") }
    
    // Periods
    static var period1Day: String { manager.localized("period.1day") }
    static var period1Week: String { manager.localized("period.1week") }
    static var period1Month: String { manager.localized("period.1month") }
    static var period1Year: String { manager.localized("period.1year") }
    static var periodYearToDate: String { manager.localized("period.yearToDate") }
    
    // Dashboard
    static var dashboardPortfolioSummary: String { manager.localized("dashboard.portfolioSummary") }
    static var dashboardPortfolioTrend: String { manager.localized("dashboard.portfolioTrend") }
    static var dashboardPortfolioValue: String { manager.localized("dashboard.portfolioValue") }
    static var dashboardPortfolioValueGold: String { manager.localized("dashboard.portfolioValueGold") }
    static var dashboardQuadrantAllocation: String { manager.localized("dashboard.quadrantAllocation") }
    static var dashboardAccountAllocation: String { manager.localized("dashboard.accountAllocation") }
    static var dashboardNoHoldings: String { manager.localized("dashboard.noHoldings") }
    static var dashboardNoHistoricalData: String { manager.localized("dashboard.noHistoricalData") }
    static var dashboardComparisonPeriod: String { manager.localized("dashboard.comparisonPeriod") }
    static var dashboardViewMode: String { manager.localized("dashboard.viewMode") }
    static var dashboardQuadrants: String { manager.localized("dashboard.quadrants") }
    static var dashboardHoldings: String { manager.localized("dashboard.holdings") }
    static var dashboardAccounts: String { manager.localized("dashboard.accounts") }
    static var dashboardTotalPortfolioValue: String { manager.localized("dashboard.totalPortfolioValue") }
    static var dashboardNoAccountsWithData: String { manager.localized("dashboard.noAccountsWithData") }
    static var dashboardNoDataAvailable: String { manager.localized("dashboard.noDataAvailable") }
    
    // Portfolio Summary
    static var summaryGold: String { manager.localized("summary.gold") }
    static var summaryFrom: String { manager.localized("summary.from") }
    static var summaryOz: String { manager.localized("summary.oz") }
    static var summaryTotalEur: String { manager.localized("summary.totalEur") }
    static var summaryLastUpdate: String { manager.localized("summary.lastUpdate") }
    
    // Instruments
    static var instrumentsTitle: String { manager.localized("instruments.title") }
    static var instrumentsQuadrants: String { manager.localized("instruments.quadrants") }
    static var instrumentsUnassigned: String { manager.localized("instruments.unassigned") }
    static var instrumentsAddInstrument: String { manager.localized("instruments.addInstrument") }
    static var instrumentsEditInstrument: String { manager.localized("instruments.editInstrument") }
    static var instrumentsIsinHint: String { manager.localized("instruments.isinHint") }
    static var instrumentsRemoveFromQuadrant: String { manager.localized("instruments.removeFromQuadrant") }
    static var instrumentsAssignToQuadrant: String { manager.localized("instruments.assignToQuadrant") }
    static var instrumentsDeleteInstrument: String { manager.localized("instruments.deleteInstrument") }
    static var instrumentsNoQuadrantsAvailable: String { manager.localized("instruments.noQuadrantsAvailable") }
    static func instrumentsCount(_ count: Int) -> String {
        String(format: manager.localized("instruments.count"), count)
    }
    
    // Accounts
    static var accountsTitle: String { manager.localized("accounts.title") }
    static var accountsAddAccount: String { manager.localized("accounts.addAccount") }
    static var accountsNoAccounts: String { manager.localized("accounts.noAccounts") }
    static var accountsOtherAccounts: String { manager.localized("accounts.otherAccounts") }
    static var accountsNoBankAccounts: String { manager.localized("accounts.noBankAccounts") }
    static var accountsAddBankAccountFirst: String { manager.localized("accounts.addBankAccountFirst") }
    static var accountsSelectAccount: String { manager.localized("accounts.selectAccount") }
    static var accountsSelectAnAccount: String { manager.localized("accounts.selectAnAccount") }
    static var accountsNoHoldingsInAccount: String { manager.localized("accounts.noHoldingsInAccount") }
    static var accountsNoHoldingsYet: String { manager.localized("accounts.noHoldingsYet") }
    static var accountsTapToAddHolding: String { manager.localized("accounts.tapToAddHolding") }
    static var accountsAcrossAllAccounts: String { manager.localized("accounts.acrossAllAccounts") }
    static func accountsHoldingsCount(_ count: Int) -> String {
        String(format: manager.localized("accounts.holdingsCount"), count)
    }
    static func accountsBankAccountsCount(_ count: Int) -> String {
        String(format: manager.localized("accounts.bankAccountsCount"), count)
    }
    static func accountsHoldingsCountTitle(_ count: Int) -> String {
        String(format: manager.localized("accounts.holdingsCountTitle"), count)
    }
    
    // Holdings
    static var holdingsAddHolding: String { manager.localized("holdings.addHolding") }
    static var holdingsSelectInstrument: String { manager.localized("holdings.selectInstrument") }
    static var holdingsSelectAnInstrument: String { manager.localized("holdings.selectAnInstrument") }
    static var holdingsSelectAnInstrumentGraph: String { manager.localized("holdings.selectAnInstrumentGraph") }
    static var holdingsPurchaseDetails: String { manager.localized("holdings.purchaseDetails") }
    static var holdingsPurchaseDetailsHint: String { manager.localized("holdings.purchaseDetailsHint") }
    static var holdingsInstrument: String { manager.localized("holdings.instrument") }
    static var holdingsValue: String { manager.localized("holdings.value") }
    static var holdingsChange: String { manager.localized("holdings.change") }
    static var holdingsQty: String { manager.localized("holdings.qty") }
    static var holdingsNoHoldings: String { manager.localized("holdings.noHoldings") }
    static var holdingsNoChartData: String { manager.localized("holdings.noChartData") }
    static func holdingsQuantityUnits(_ quantity: String) -> String {
        String(format: manager.localized("holdings.quantityUnits"), quantity)
    }
    
    // Quadrants
    static var quadrantsAddQuadrant: String { manager.localized("quadrants.addQuadrant") }
    static var quadrantsQuadrantDetails: String { manager.localized("quadrants.quadrantDetails") }
    static var quadrantsQuadrantDetailsHint: String { manager.localized("quadrants.quadrantDetailsHint") }
    static var quadrantsQuadrantAssignment: String { manager.localized("quadrants.quadrantAssignment") }
    static var quadrantsQuadrantAssignmentHint: String { manager.localized("quadrants.quadrantAssignmentHint") }
    static var quadrantsCategorizeHint: String { manager.localized("quadrants.categorizeHint") }
    static func quadrantsCount(_ count: Int) -> String {
        String(format: manager.localized("quadrants.quadrantsCount"), count)
    }
    
    // Reports
    static var reportsQuadrantReport: String { manager.localized("reports.quadrantReport") }
    static var reportsComparisonPeriod: String { manager.localized("reports.comparisonPeriod") }
    static var reportsNoHoldingsToDisplay: String { manager.localized("reports.noHoldingsToDisplay") }
    static var reportsAddInstrumentsHint: String { manager.localized("reports.addInstrumentsHint") }
    static var reportsNoPriceHistoryAvailable: String { manager.localized("reports.noPriceHistoryAvailable") }
    static var reportsClickToAddPrice: String { manager.localized("reports.clickToAddPrice") }
    static var reportsNoPriceDataForPeriod: String { manager.localized("reports.noPriceDataForPeriod") }
    static func reportsVs(_ date: String) -> String {
        String(format: manager.localized("reports.vs"), date)
    }
    static func reportsAsOf(_ date: String) -> String {
        String(format: manager.localized("reports.asOf"), date)
    }
    static func reportsDeleteConfirmation(_ date: String) -> String {
        String(format: manager.localized("reports.deleteConfirmation"), date)
    }
    
    // Stats
    static var statsBestPerformer: String { manager.localized("stats.bestPerformer") }
    static var statsWorstPerformer: String { manager.localized("stats.worstPerformer") }
    static var statsLargestPosition: String { manager.localized("stats.largestPosition") }
    static var statsTotalHoldings: String { manager.localized("stats.totalHoldings") }
    static func statsMoreItems(_ count: Int) -> String {
        String(format: manager.localized("stats.moreItems"), count)
    }
    
    // Settings
    static var settingsTitle: String { manager.localized("settings.title") }
    static var settingsDemoMode: String { manager.localized("settings.demoMode") }
    static var settingsDemoModeDescription: String { manager.localized("settings.demoModeDescription") }
    static var settingsDemoModeEnable: String { manager.localized("settings.demoModeEnable") }
    static var settingsDemoModeActive: String { manager.localized("settings.demoModeActive") }
    static var settingsDemoModeRandomize: String { manager.localized("settings.demoModeRandomize") }
    static var settingsLanguage: String { manager.localized("settings.language") }
    static var settingsLanguageDescription: String { manager.localized("settings.languageDescription") }
    static var settingsEnglish: String { manager.localized("settings.english") }
    static var settingsFrench: String { manager.localized("settings.french") }
    static var settingsDataManagement: String { manager.localized("settings.dataManagement") }
    static var settingsUpdatePrices: String { manager.localized("settings.updatePrices") }
    static var settingsBackfillData: String { manager.localized("settings.backfillData") }
    static var settingsAbout: String { manager.localized("settings.about") }
    static var settingsVersion: String { manager.localized("settings.version") }
    static var settingsGeneral: String { manager.localized("settings.general") }
    static var settingsDatabase: String { manager.localized("settings.database") }
    static var settingsBackground: String { manager.localized("settings.background") }
    static var settingsStorage: String { manager.localized("settings.storage") }
    static var settingsStorageDescription: String { manager.localized("settings.storageDescription") }
    static var settingsImportExportHint: String { manager.localized("settings.importExportHint") }
    static var settingsLocalStorage: String { manager.localized("settings.localStorage") }
    static var settingsLocalStorageOnly: String { manager.localized("settings.localStorageOnly") }
    static var settingsSyncingWithICloud: String { manager.localized("settings.syncingWithICloud") }
    static var settingsICloudRequirement: String { manager.localized("settings.iCloudRequirement") }
    static var settingsImportDatabase: String { manager.localized("settings.importDatabase") }
    static var settingsExportDatabase: String { manager.localized("settings.exportDatabase") }
    static var settingsOpenInFinder: String { manager.localized("settings.openInFinder") }
    static var settingsMoveData: String { manager.localized("settings.moveData") }
    static var settingsStartFresh: String { manager.localized("settings.startFresh") }
    static var settingsPrivacyMode: String { manager.localized("settings.privacyMode") }
    static var settingsBackgroundRefresh: String { manager.localized("settings.backgroundRefresh") }
    static var settingsBackgroundRefreshInterval: String { manager.localized("settings.backgroundRefreshInterval") }
    static var settingsLastRefresh: String { manager.localized("settings.lastRefresh") }
    static var settingsBackgroundUpdates: String { manager.localized("settings.backgroundUpdates") }
    static var settingsBackgroundUpdatesDescription: String { manager.localized("settings.backgroundUpdatesDescription") }
    static var settingsAutomaticUpdates: String { manager.localized("settings.automaticUpdates") }
    static var settingsAutomaticUpdatesDescription: String { manager.localized("settings.automaticUpdatesDescription") }
    static var settingsStatusActive: String { manager.localized("settings.statusActive") }
    static var settingsStatusInstalledNotRunning: String { manager.localized("settings.statusInstalledNotRunning") }
    static var settingsStatusNotInstalled: String { manager.localized("settings.statusNotInstalled") }
    static var settingsEnable: String { manager.localized("settings.enable") }
    static var settingsDisable: String { manager.localized("settings.disable") }
    static var settingsRunNow: String { manager.localized("settings.runNow") }
    static var settingsRefreshStatus: String { manager.localized("settings.refreshStatus") }
    static var settingsRecentActivity: String { manager.localized("settings.recentActivity") }
    static var settingsOpenLogsFolder: String { manager.localized("settings.openLogsFolder") }
    static var settingsNoLogsAvailable: String { manager.localized("settings.noLogsAvailable") }
    static var settingsLogsDescription: String { manager.localized("settings.logsDescription") }
    static var settingsBackgroundRefreshLogs: String { manager.localized("settings.backgroundRefreshLogs") }
    static var settingsAccountDetails: String { manager.localized("settings.accountDetails") }
    static var settingsAccountDetailsHint: String { manager.localized("settings.accountDetailsHint") }
    static var settingsUpdatePricesDescription: String { manager.localized("settings.updatePricesDescription") }
    static func settingsMoveDataConfirmation(_ storage: String) -> String {
        String(format: manager.localized("settings.moveDataConfirmation"), storage)
    }
    
    // Actions
    static var actionUpdatePrices: String { manager.localized("action.updatePrices") }
    static var actionUpdateAllPrices: String { manager.localized("action.updateAllPrices") }
    static var actionBackfill1Year: String { manager.localized("action.backfill1Year") }
    static var actionBackfill2Years: String { manager.localized("action.backfill2Years") }
    static var actionBackfill5Years: String { manager.localized("action.backfill5Years") }
    static var actionBackfill1Month: String { manager.localized("action.backfill1Month") }
    static var actionBackfillHistorical1Year: String { manager.localized("action.backfillHistorical1Year") }
    static var actionBackfillHistorical2Years: String { manager.localized("action.backfillHistorical2Years") }
    static var actionBackfillHistorical5Years: String { manager.localized("action.backfillHistorical5Years") }
    static var actionAddPrice: String { manager.localized("action.addPrice") }
    static var actionEditPrice: String { manager.localized("action.editPrice") }
    
    // Chart
    static var chartNoGoldPriceData: String { manager.localized("chart.noGoldPriceData") }
    static var chartClickToToggle: String { manager.localized("chart.clickToToggle") }
    static var chartNoPriceHistory: String { manager.localized("chart.noPriceHistory") }
    static var chartPortfolioLabel: String { manager.localized("chart.portfolioLabel") }
    static var chartSp500Comparison: String { manager.localized("chart.sp500Comparison") }
    static var chartGoldComparison: String { manager.localized("chart.goldComparison") }
    static var chartMsciWorldComparison: String { manager.localized("chart.msciWorldComparison") }
    static func chartDataPoints(_ count: Int) -> String {
        String(format: manager.localized("chart.dataPoints"), count)
    }
    
    // Privacy
    static var privacyHidden: String { manager.localized("privacy.hidden") }
    static var privacyHiddenLong: String { manager.localized("privacy.hiddenLong") }
    static var privacyHiddenStars: String { manager.localized("privacy.hiddenStars") }
    
    // Tooltips
    static var tooltipUpdateAllPrices: String { manager.localized("tooltip.updateAllPrices") }
    static var tooltipBackfillHistoricalData: String { manager.localized("tooltip.backfillHistoricalData") }
    static var tooltipAddPrice: String { manager.localized("tooltip.addPrice") }
    static var tooltipEdit: String { manager.localized("tooltip.edit") }
    static var tooltipDelete: String { manager.localized("tooltip.delete") }
    
    // Refresh Result
    static var refreshSuccess: String { manager.localized("refresh.success") }
    static var refreshPartial: String { manager.localized("refresh.partial") }
    static var refreshFailed: String { manager.localized("refresh.failed") }
    static var refreshFailedInstruments: String { manager.localized("refresh.failedInstruments") }
    static var refreshDebugReasons: String { manager.localized("refresh.debugReasons") }
    static func refreshSuccessDetail(_ count: Int) -> String {
        String(format: manager.localized("refresh.successDetail"), count)
    }
    static func refreshResultDetail(_ success: Int, _ total: Int) -> String {
        String(format: manager.localized("refresh.resultDetail"), success, total)
    }
    
    // Errors
    static var errorFetchFailed: String { manager.localized("error.fetchFailed") }
    static var errorSaveFailed: String { manager.localized("error.saveFailed") }
    static var errorDeleteFailed: String { manager.localized("error.deleteFailed") }
}
