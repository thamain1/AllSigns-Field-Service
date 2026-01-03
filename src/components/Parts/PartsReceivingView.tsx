import { useState, useEffect } from 'react';
import { PackageCheck, Plus, Search, Calendar, Package } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';
import { ReceivingModal } from './ReceivingModal';

type PurchaseOrder = Database['public']['Tables']['purchase_orders']['Row'];
type Vendor = Database['public']['Tables']['vendors']['Row'];

interface PurchaseOrderWithVendor extends PurchaseOrder {
  vendors: Vendor;
  line_count?: number;
}

interface PartsReceivingViewProps {
  onNavigateToOrders: () => void;
}

export function PartsReceivingView({ onNavigateToOrders }: PartsReceivingViewProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [purchaseOrders, setPurchaseOrders] = useState<PurchaseOrderWithVendor[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedPOId, setSelectedPOId] = useState<string | null>(null);
  const [stats, setStats] = useState({
    pending: 0,
    receivedToday: 0,
    receivedThisWeek: 0,
    discrepancies: 0,
  });

  useEffect(() => {
    loadPurchaseOrders();
  }, []);

  const loadPurchaseOrders = async () => {
    try {
      setLoading(true);

      const { data: orders, error } = await supabase
        .from('purchase_orders')
        .select(`
          *,
          vendors (*)
        `)
        .in('status', ['submitted', 'approved', 'partial'])
        .order('expected_delivery_date', { ascending: true });

      if (error) throw error;

      const ordersWithCount = await Promise.all(
        (orders || []).map(async (order) => {
          const { count } = await supabase
            .from('purchase_order_lines')
            .select('*', { count: 'exact', head: true })
            .eq('po_id', order.id);

          return {
            ...order,
            line_count: count || 0,
          };
        })
      );

      setPurchaseOrders(ordersWithCount as PurchaseOrderWithVendor[]);

      setStats({
        pending: ordersWithCount.filter((o) => o.status === 'approved' || o.status === 'submitted').length,
        receivedToday: 0,
        receivedThisWeek: 0,
        discrepancies: 0,
      });
    } catch (error) {
      console.error('Error loading purchase orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges: Record<string, string> = {
      draft: 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300',
      submitted: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
      approved: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
      partial: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400',
      received: 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300',
      cancelled: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
    };
    return badges[status] || badges.draft;
  };

  const formatDate = (dateString: string | null) => {
    if (!dateString) return 'Not set';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const filteredOrders = purchaseOrders.filter((order) => {
    const searchLower = searchTerm.toLowerCase();
    return (
      order.po_number.toLowerCase().includes(searchLower) ||
      order.vendors.name.toLowerCase().includes(searchLower)
    );
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Parts Receiving</h2>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Check in incoming parts, capture serial numbers and warranties, and place them into stock locations
          </p>
        </div>
        <button
          onClick={onNavigateToOrders}
          className="btn-primary flex items-center space-x-2"
        >
          <Plus className="w-5 h-5" />
          <span>Create Purchase Order</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Pending Receipts', value: stats.pending.toString(), color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400' },
          { label: 'Received Today', value: stats.receivedToday.toString(), color: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400' },
          { label: 'This Week', value: stats.receivedThisWeek.toString(), color: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400' },
          { label: 'Discrepancies', value: stats.discrepancies.toString(), color: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400' },
        ].map((stat) => (
          <div key={stat.label} className="card p-4">
            <p className="text-sm text-gray-600 dark:text-gray-400">{stat.label}</p>
            <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{stat.value}</p>
          </div>
        ))}
      </div>

      <div className="card">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by PO number, vendor, or part..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input pl-10"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  PO Number
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Vendor
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Expected Date
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Items
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                    Loading purchase orders...
                  </td>
                </tr>
              ) : filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center">
                    <div className="flex flex-col items-center space-y-3">
                      <div className="p-4 bg-gray-100 dark:bg-gray-800 rounded-full">
                        <PackageCheck className="w-8 h-8 text-gray-400" />
                      </div>
                      <div>
                        <p className="text-gray-900 dark:text-white font-medium">
                          {searchTerm ? 'No matching purchase orders' : 'No pending shipments'}
                        </p>
                        <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                          {searchTerm
                            ? 'Try adjusting your search terms'
                            : 'When purchase orders are ready to receive, they\'ll appear here'}
                        </p>
                      </div>
                      {!searchTerm && (
                        <button
                          onClick={onNavigateToOrders}
                          className="btn-primary flex items-center space-x-2 mt-4"
                        >
                          <Plus className="w-4 h-4" />
                          <span>Create Purchase Order</span>
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ) : (
                filteredOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                    <td className="px-4 py-3">
                      <div className="font-medium text-gray-900 dark:text-white">
                        {order.po_number}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-gray-900 dark:text-white">
                        {order.vendors.name}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center space-x-2 text-gray-600 dark:text-gray-400">
                        <Calendar className="w-4 h-4" />
                        <span>{formatDate(order.expected_delivery_date)}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusBadge(
                          order.status
                        )}`}
                      >
                        {order.status.charAt(0).toUpperCase() + order.status.slice(1)}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center space-x-2 text-gray-600 dark:text-gray-400">
                        <Package className="w-4 h-4" />
                        <span>{order.line_count || 0} items</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => setSelectedPOId(order.id)}
                        className="btn-primary text-sm"
                      >
                        Start Receiving
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
            Recent Receiving History
          </h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  PO Number
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Vendor
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Parts Received
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Location
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Received By
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                  No receiving history yet
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="card bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800">
        <div className="p-4">
          <h3 className="font-semibold text-blue-900 dark:text-blue-100 mb-2">
            Parts Receiving Workflow
          </h3>
          <div className="text-sm text-blue-800 dark:text-blue-200 space-y-2">
            <p className="flex items-start">
              <span className="font-semibold mr-2">1.</span>
              <span>Match delivery to Purchase Order and verify contents</span>
            </p>
            <p className="flex items-start">
              <span className="font-semibold mr-2">2.</span>
              <span>Record quantities received, damaged, or short</span>
            </p>
            <p className="flex items-start">
              <span className="font-semibold mr-2">3.</span>
              <span>Capture serial numbers and warranty information for tracked items</span>
            </p>
            <p className="flex items-start">
              <span className="font-semibold mr-2">4.</span>
              <span>Assign parts to stock locations (warehouse, truck, or project)</span>
            </p>
            <p className="flex items-start">
              <span className="font-semibold mr-2">5.</span>
              <span>System automatically creates inventory transactions and updates vendor performance</span>
            </p>
          </div>
        </div>
      </div>

      {selectedPOId && (
        <ReceivingModal
          purchaseOrderId={selectedPOId}
          onClose={() => setSelectedPOId(null)}
          onComplete={() => {
            setSelectedPOId(null);
            loadPurchaseOrders();
          }}
        />
      )}
    </div>
  );
}
