import { useState } from 'react';
import { LogOut } from 'lucide-react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { LoginForm } from './components/Auth/LoginForm';
import { SidebarNew } from './components/Layout/SidebarNew';
import { DashboardView } from './components/Dashboard/DashboardView';
import { TicketsView } from './components/Tickets/TicketsView';
import { DispatchView } from './components/Dispatch/DispatchView';
import { TrackingView } from './components/Tracking/TrackingView';
import { MappingView } from './components/Mapping/MappingView';
import { PartsManagementView } from './components/Parts/PartsManagementView';
import { EquipmentView } from './components/Equipment/EquipmentView';
import { VendorsView } from './components/Vendors/VendorsView';
import { ProjectsView } from './components/Projects/ProjectsView';
import { CustomersView } from './components/Customers/CustomersView';
import { InvoicingView } from './components/Invoicing/InvoicingView';
import { TimeClockView } from './components/Tracking/TimeClockView';
import { AccountingView } from './components/Accounting/AccountingView';
import { PayrollView } from './components/Payroll/PayrollView';
import { ReportsView } from './components/Reports/ReportsView';
import { SettingsView } from './components/Settings/SettingsView';
import { EstimatesViewContainer } from './components/Estimates/EstimatesViewContainer';
import { DataImportView } from './components/DataImport/DataImportView';
import { ServiceContractsView } from './components/Contracts/ServiceContractsView';
import { ContractPlansView } from './components/Contracts/ContractPlansView';

function AppContent() {
  const { user, loading, signOut } = useAuth();
  const [currentView, setCurrentView] = useState('dashboard');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-900">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!user) {
    return <LoginForm />;
  }

  const handleViewChange = (view: string) => {
    setCurrentView(view);
    setIsMobileMenuOpen(false);
  };

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return <DashboardView />;
      case 'tickets':
        return <TicketsView />;
      case 'estimates':
        return <EstimatesViewContainer />;
      case 'dispatch':
        return <DispatchView />;
      case 'tracking':
        return <TrackingView />;
      case 'mapping':
        return <MappingView />;
      case 'parts':
      case 'parts-inventory':
      case 'parts-purchase-orders':
      case 'parts-transfers':
      case 'parts-receiving':
      case 'parts-receipts':
        return <PartsManagementView initialView={currentView} />;
      case 'equipment':
      case 'equipment-installed':
      case 'equipment-parts':
      case 'equipment-warranty':
        return <EquipmentView />;
      case 'vendors':
      case 'vendors-list':
        return <VendorsView initialTab="list" />;
      case 'vendors-contracts':
        return <VendorsView initialTab="contracts" />;
      case 'vendors-performance':
        return <VendorsView initialTab="performance" />;
      case 'vendors-payments':
        return <VendorsView initialTab="payments" />;
      case 'projects':
      case 'projects-overview':
      case 'projects-gantt':
      case 'projects-budget':
        return <ProjectsView />;
      case 'customers':
        return <CustomersView />;
      case 'service-contracts':
        return <ServiceContractsView />;
      case 'invoicing':
        return <InvoicingView />;
      case 'timeclock':
        return <TimeClockView />;
      case 'accounting':
        return <AccountingView initialView="dashboard" />;
      case 'accounting-ledger':
        return <AccountingView initialView="general-ledger" />;
      case 'accounting-ar-ap':
        return <AccountingView initialView="ar-ap" />;
      case 'accounting-chart':
        return <AccountingView initialView="chart-of-accounts" />;
      case 'accounting-reconciliation':
        return <AccountingView initialView="reconciliations" />;
      case 'payroll':
      case 'payroll-runs':
      case 'payroll-time-cost':
      case 'payroll-stubs':
        return <PayrollView />;
      case 'reports':
      case 'reports-job-cost':
      case 'reports-financials':
      case 'reports-technician':
      case 'reports-margins':
        return <ReportsView />;
      case 'settings':
      case 'settings-users':
      case 'settings-labor-rates':
      case 'settings-notifications':
      case 'settings-permissions':
        return <SettingsView />;
      case 'settings-contract-plans':
        return <ContractPlansView />;
      case 'data-import':
        return <DataImportView />;
      default:
        return <DashboardView />;
    }
  };

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50 dark:bg-gray-900">
      {/* Mobile overlay */}
      {isMobileMenuOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 md:hidden"
          onClick={() => setIsMobileMenuOpen(false)}
        />
      )}

      {/* Sidebar - hidden on mobile by default, slides in when menu is open */}
      <div
        className={`fixed md:static inset-y-0 left-0 z-50 transform transition-transform duration-300 ease-in-out ${
          isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
        }`}
      >
        <SidebarNew currentView={currentView} onViewChange={handleViewChange} />
      </div>

      {/* Main content area */}
      <main className="flex-1 overflow-y-auto flex flex-col w-full">
        {/* Mobile header with hamburger menu */}
        <div className="md:hidden bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-4 py-2 flex items-center justify-between sticky top-0 z-30">
          <button
            onClick={() => setIsMobileMenuOpen(true)}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <svg
              className="w-6 h-6 text-gray-900 dark:text-white"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="2"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path d="M4 6h16M4 12h16M4 18h16"></path>
            </svg>
          </button>
          <img
            src="/image.png"
            alt="Dunaway Logo"
            className="h-12 w-auto object-contain"
          />
          <button
            onClick={signOut}
            className="p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400"
            title="Sign Out"
          >
            <LogOut className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 p-4 sm:p-6 md:p-8">{renderView()}</div>
        <footer className="bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 py-3 px-4 sm:px-8">
          <p className="text-center text-xs sm:text-sm text-gray-600 dark:text-gray-400">
            Powered by <span className="font-semibold text-gray-900 dark:text-white">4wardmotions Inc</span>
          </p>
        </footer>
      </main>
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
