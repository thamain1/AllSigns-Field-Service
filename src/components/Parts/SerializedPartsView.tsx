import { useEffect, useState } from 'react';
import { Hash, Package, MapPin, Plus, Search, Calendar, Truck, CheckCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';
import { inventoryService } from '../../services/InventoryService';

type SerializedPart = Database['public']['Tables']['serialized_parts']['Row'] & {
  parts?: { name: string; part_number: string };
  vendors?: { name: string };
  stock_locations?: { name: string; location_type: string };
};

type SerializedPartStatus = 'in_stock' | 'in_transit' | 'installed' | 'returned' | 'defective' | 'warranty_claim';

export function SerializedPartsView() {
  const [serializedParts, setSerializedParts] = useState<SerializedPart[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [showAddModal, setShowAddModal] = useState(false);

  useEffect(() => {
    loadSerializedParts();
  }, [statusFilter]);

  const loadSerializedParts = async () => {
    try {
      let query = supabase
        .from('serialized_parts')
        .select(`
          *,
          parts(name, part_number),
          vendors(name),
          stock_locations(name, location_type)
        `);

      if (statusFilter !== 'all') {
        if (statusFilter === 'available') {
          query = query.in('status', ['in_stock', 'in_transit']).is('installed_on_equipment_id', null);
        } else if (statusFilter === 'installed') {
          query = query.eq('status', 'installed');
        } else {
          query = query.eq('status', statusFilter);
        }
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;
      setSerializedParts(data || []);
    } catch (error) {
      console.error('Error loading serialized parts:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredParts = serializedParts.filter((part) => {
    const matchesSearch =
      part.serial_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      part.parts?.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      part.parts?.part_number.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesStatus = statusFilter === 'all' || part.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  const statusCounts = {
    all: serializedParts.length,
    in_stock: serializedParts.filter((p) => p.status === 'in_stock').length,
    installed: serializedParts.filter((p) => p.status === 'installed').length,
    in_transit: serializedParts.filter((p) => p.status === 'in_transit').length,
    defective: serializedParts.filter((p) => p.status === 'defective').length,
  };

  const getStatusColor = (status: SerializedPartStatus) => {
    switch (status) {
      case 'in_stock':
        return 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400';
      case 'installed':
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400';
      case 'in_transit':
        return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400';
      case 'defective':
      case 'warranty_claim':
        return 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400';
      case 'returned':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
    }
  };

  const formatStatus = (status: string) => {
    return status
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
            Serialized Inventory
          </h2>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Track individual parts with serial numbers
          </p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="btn-primary flex items-center space-x-2"
        >
          <Plus className="w-5 h-5" />
          <span>Add Serialized Part</span>
        </button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {[
          { id: 'all', label: 'All Parts', count: statusCounts.all, icon: Package },
          { id: 'in_stock', label: 'In Stock', count: statusCounts.in_stock, icon: Package },
          { id: 'installed', label: 'Installed', count: statusCounts.installed, icon: MapPin },
          { id: 'in_transit', label: 'In Transit', count: statusCounts.in_transit, icon: Truck },
          { id: 'defective', label: 'Defective', count: statusCounts.defective, icon: Hash },
        ].map((stat) => {
          const Icon = stat.icon;
          return (
            <button
              key={stat.id}
              onClick={() => setStatusFilter(stat.id)}
              className={`card p-4 text-left transition-all ${
                statusFilter === stat.id
                  ? 'ring-2 ring-blue-500 dark:ring-blue-400'
                  : 'hover:shadow-md'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">{stat.label}</p>
                  <p className="text-2xl font-bold text-gray-900 dark:text-white mt-1">
                    {stat.count}
                  </p>
                </div>
                <div className="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                  <Icon className="w-6 h-6 text-blue-600 dark:text-blue-400" />
                </div>
              </div>
            </button>
          );
        })}
      </div>

      <div className="card">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by serial number or part name..."
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
                  Serial Number
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Part
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Location
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Vendor
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Purchase Date
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Cost
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
              {filteredParts.length === 0 ? (
                <tr>
                  <td
                    colSpan={7}
                    className="px-4 py-8 text-center text-gray-500 dark:text-gray-400"
                  >
                    {searchTerm || statusFilter !== 'all'
                      ? 'No serialized parts match your filters'
                      : 'No serialized parts yet'}
                  </td>
                </tr>
              ) : (
                filteredParts.map((part) => (
                  <tr key={part.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                    <td className="px-4 py-3">
                      <div className="flex items-center space-x-2">
                        <Hash className="w-4 h-4 text-gray-400" />
                        <span className="font-mono text-sm font-medium text-gray-900 dark:text-white">
                          {part.serial_number}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium text-gray-900 dark:text-white">
                        {part.parts?.name}
                      </div>
                      <div className="text-sm text-gray-500 dark:text-gray-400">
                        {part.parts?.part_number}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(
                          part.status as SerializedPartStatus
                        )}`}
                      >
                        {formatStatus(part.status)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-white">
                      {part.stock_locations?.name || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-white">
                      {part.vendors?.name || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                      {part.purchase_date ? (
                        <div className="flex items-center space-x-1">
                          <Calendar className="w-4 h-4" />
                          <span>{new Date(part.purchase_date).toLocaleDateString()}</span>
                        </div>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">
                      {part.unit_cost ? `$${parseFloat(part.unit_cost as any).toFixed(2)}` : '-'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg max-w-lg w-full">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                Add Serialized Part
              </h2>
            </div>
            <div className="p-6">
              <p className="text-gray-600 dark:text-gray-400">
                Serialized parts are typically added when receiving purchase orders with serial
                numbers. This feature is integrated with the PO receiving workflow.
              </p>
            </div>
            <div className="p-6 border-t border-gray-200 dark:border-gray-700 flex justify-end">
              <button onClick={() => setShowAddModal(false)} className="btn-secondary">
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
