import { useEffect, useState } from 'react';
import { Shield, AlertTriangle, CheckCircle, Clock, Search, Calendar } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';

type WarrantyRecord = Database['public']['Tables']['warranty_records']['Row'] & {
  serialized_parts?: {
    serial_number: string;
    parts?: { name: string; part_number: string };
  };
  vendors?: { name: string };
};

type WarrantyStatus = 'active' | 'expired' | 'claimed' | 'void';

export function WarrantyDashboard() {
  const [warranties, setWarranties] = useState<WarrantyRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  useEffect(() => {
    loadWarranties();
  }, []);

  const loadWarranties = async () => {
    try {
      const { data, error } = await supabase
        .from('warranty_records')
        .select(`
          *,
          serialized_parts(
            serial_number,
            parts(name, part_number)
          ),
          vendors(name)
        `)
        .order('end_date', { ascending: true });

      if (error) throw error;
      setWarranties(data || []);
    } catch (error) {
      console.error('Error loading warranties:', error);
    } finally {
      setLoading(false);
    }
  };

  const getWarrantyStatus = (warranty: WarrantyRecord): WarrantyStatus => {
    const now = new Date();
    const endDate = new Date(warranty.end_date);

    if (warranty.warranty_status === 'void' || warranty.warranty_status === 'claimed') {
      return warranty.warranty_status as WarrantyStatus;
    }

    if (endDate < now) {
      return 'expired';
    }

    return 'active';
  };

  const getDaysRemaining = (endDate: string) => {
    const now = new Date();
    const end = new Date(endDate);
    const diffTime = end.getTime() - now.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
  };

  const filteredWarranties = warranties.filter((warranty) => {
    const matchesSearch =
      warranty.serialized_parts?.serial_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      warranty.serialized_parts?.parts?.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      warranty.warranty_number?.toLowerCase().includes(searchTerm.toLowerCase());

    const status = getWarrantyStatus(warranty);
    const matchesStatus = statusFilter === 'all' || status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  const statusCounts = {
    all: warranties.length,
    active: warranties.filter((w) => getWarrantyStatus(w) === 'active').length,
    expiring_soon: warranties.filter((w) => {
      const status = getWarrantyStatus(w);
      const daysRemaining = getDaysRemaining(w.end_date);
      return status === 'active' && daysRemaining <= 30;
    }).length,
    expired: warranties.filter((w) => getWarrantyStatus(w) === 'expired').length,
    claimed: warranties.filter((w) => w.warranty_status === 'claimed').length,
  };

  const getStatusColor = (status: WarrantyStatus) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400';
      case 'expired':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
      case 'claimed':
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400';
      case 'void':
        return 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400';
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
    }
  };

  const getWarrantyTypeLabel = (type: string) => {
    return type
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
      <div>
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Warranty Tracking</h2>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Monitor warranty status and expiration dates
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {[
          { id: 'all', label: 'All Warranties', count: statusCounts.all, icon: Shield },
          {
            id: 'active',
            label: 'Active',
            count: statusCounts.active,
            icon: CheckCircle,
            color: 'text-green-600 dark:text-green-400',
          },
          {
            id: 'expiring_soon',
            label: 'Expiring Soon',
            count: statusCounts.expiring_soon,
            icon: AlertTriangle,
            color: 'text-yellow-600 dark:text-yellow-400',
          },
          {
            id: 'expired',
            label: 'Expired',
            count: statusCounts.expired,
            icon: Clock,
            color: 'text-gray-600 dark:text-gray-400',
          },
          {
            id: 'claimed',
            label: 'Claimed',
            count: statusCounts.claimed,
            icon: Shield,
            color: 'text-blue-600 dark:text-blue-400',
          },
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
                  <Icon className={`w-6 h-6 ${stat.color || 'text-blue-600 dark:text-blue-400'}`} />
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
              placeholder="Search by serial number, part name, or warranty number..."
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
                  Type
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Vendor
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Start Date
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  End Date
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Days Remaining
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
              {filteredWarranties.length === 0 ? (
                <tr>
                  <td
                    colSpan={8}
                    className="px-4 py-8 text-center text-gray-500 dark:text-gray-400"
                  >
                    {searchTerm || statusFilter !== 'all'
                      ? 'No warranties match your filters'
                      : 'No warranty records yet'}
                  </td>
                </tr>
              ) : (
                filteredWarranties.map((warranty) => {
                  const status = getWarrantyStatus(warranty);
                  const daysRemaining = getDaysRemaining(warranty.end_date);
                  const isExpiringSoon = status === 'active' && daysRemaining <= 30;

                  return (
                    <tr
                      key={warranty.id}
                      className={`hover:bg-gray-50 dark:hover:bg-gray-800 ${
                        isExpiringSoon ? 'bg-yellow-50 dark:bg-yellow-900/10' : ''
                      }`}
                    >
                      <td className="px-4 py-3">
                        <span className="font-mono text-sm font-medium text-gray-900 dark:text-white">
                          {warranty.serialized_parts?.serial_number || '-'}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="font-medium text-gray-900 dark:text-white">
                          {warranty.serialized_parts?.parts?.name}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                          {warranty.serialized_parts?.parts?.part_number}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-900 dark:text-white">
                        {getWarrantyTypeLabel(warranty.warranty_type)}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(
                            status
                          )}`}
                        >
                          {status.charAt(0).toUpperCase() + status.slice(1)}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-900 dark:text-white">
                        {warranty.vendors?.name || '-'}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                        <div className="flex items-center space-x-1">
                          <Calendar className="w-4 h-4" />
                          <span>{new Date(warranty.start_date).toLocaleDateString()}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                        <div className="flex items-center space-x-1">
                          <Calendar className="w-4 h-4" />
                          <span>{new Date(warranty.end_date).toLocaleDateString()}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        {status === 'active' ? (
                          <div
                            className={`flex items-center space-x-1 ${
                              isExpiringSoon
                                ? 'text-yellow-600 dark:text-yellow-400 font-semibold'
                                : 'text-gray-600 dark:text-gray-400'
                            }`}
                          >
                            <Clock className="w-4 h-4" />
                            <span>{daysRemaining} days</span>
                            {isExpiringSoon && <AlertTriangle className="w-4 h-4 ml-1" />}
                          </div>
                        ) : (
                          <span className="text-gray-400">-</span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {statusCounts.expiring_soon > 0 && (
        <div className="card bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800">
          <div className="p-4 flex items-start space-x-3">
            <AlertTriangle className="w-5 h-5 text-yellow-600 dark:text-yellow-400 flex-shrink-0 mt-0.5" />
            <div>
              <h3 className="font-semibold text-yellow-900 dark:text-yellow-100">
                Warranties Expiring Soon
              </h3>
              <p className="text-sm text-yellow-800 dark:text-yellow-200 mt-1">
                {statusCounts.expiring_soon} {statusCounts.expiring_soon === 1 ? 'warranty' : 'warranties'} will expire within the next 30 days. Review coverage options and consider renewing or replacing parts.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
