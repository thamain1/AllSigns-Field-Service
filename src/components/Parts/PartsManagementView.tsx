import { useState, useEffect } from 'react';
import { Package, Truck, ShoppingCart, Hash, Shield, MapPin, ArrowRightLeft, PackageCheck } from 'lucide-react';
import { PartsView } from './PartsView';
import { VendorsView } from './VendorsView';
import { PurchaseOrdersView } from './PurchaseOrdersView';
import { SerializedPartsView } from './SerializedPartsView';
import { StockLocationsView } from './StockLocationsView';
import { WarrantyDashboard } from './WarrantyDashboard';
import { PartsTransferView } from './PartsTransferView';
import { PartsReceivingView } from './PartsReceivingView';

type TabType = 'catalog' | 'vendors' | 'orders' | 'serialized' | 'locations' | 'warranty' | 'transfers' | 'receiving';

interface PartsManagementViewProps {
  initialView?: string;
}

export function PartsManagementView({ initialView }: PartsManagementViewProps) {
  const getInitialTab = (): TabType => {
    switch (initialView) {
      case 'parts-inventory':
        return 'locations';
      case 'parts-purchase-orders':
        return 'orders';
      case 'parts-transfers':
        return 'transfers';
      case 'parts-receiving':
        return 'receiving';
      case 'parts-receipts':
        return 'receiving';
      default:
        return 'catalog';
    }
  };

  const [activeTab, setActiveTab] = useState<TabType>(getInitialTab());

  useEffect(() => {
    setActiveTab(getInitialTab());
  }, [initialView]);

  const tabs: Array<{ id: TabType; label: string; icon: typeof Package }> = [
    { id: 'catalog', label: 'Parts Catalog', icon: Package },
    { id: 'vendors', label: 'Vendors', icon: Truck },
    { id: 'orders', label: 'Purchase Orders', icon: ShoppingCart },
    { id: 'serialized', label: 'Serialized Inventory', icon: Hash },
    { id: 'locations', label: 'Stock Locations', icon: MapPin },
    { id: 'transfers', label: 'Transfers', icon: ArrowRightLeft },
    { id: 'receiving', label: 'Receiving', icon: PackageCheck },
    { id: 'warranty', label: 'Warranty Tracking', icon: Shield },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Parts Management</h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Comprehensive parts ordering, tracking, serialization & warranty system
        </p>
      </div>

      <div className="card p-1">
        <div className="grid grid-cols-2 md:grid-cols-8 gap-1">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-3 px-4 rounded-lg font-medium transition-colors flex items-center justify-center space-x-2 ${
                  activeTab === tab.id
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
                }`}
              >
                <Icon className="w-5 h-5" />
                <span className="hidden md:inline">{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="mt-6">
        {activeTab === 'catalog' && <PartsView />}
        {activeTab === 'vendors' && <VendorsView />}
        {activeTab === 'orders' && <PurchaseOrdersView />}
        {activeTab === 'serialized' && <SerializedPartsView />}
        {activeTab === 'locations' && <StockLocationsView />}
        {activeTab === 'transfers' && <PartsTransferView />}
        {activeTab === 'receiving' && <PartsReceivingView onNavigateToOrders={() => setActiveTab('orders')} />}
        {activeTab === 'warranty' && <WarrantyDashboard />}
      </div>
    </div>
  );
}
