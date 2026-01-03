import { useEffect, useState } from 'react';
import { FileText, Plus, Search, Calendar, DollarSign, TrendingUp, Users } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';
import { ContractDetailModal } from './ContractDetailModal';
import { NewContractModal } from './NewContractModal';

type ServiceContract = Database['public']['Tables']['service_contracts']['Row'] & {
  customers?: { name: string; email: string };
  customer_locations?: { location_name: string; address: string };
  contract_plans?: { name: string };
};

type ContractStatus = 'draft' | 'active' | 'expired' | 'cancelled' | 'suspended';

export function ServiceContractsView() {
  const [contracts, setContracts] = useState<ServiceContract[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [selectedContract, setSelectedContract] = useState<ServiceContract | null>(null);
  const [showNewModal, setShowNewModal] = useState(false);
  const [stats, setStats] = useState({
    activeContracts: 0,
    totalRevenue: 0,
    expiringNext30Days: 0,
  });

  useEffect(() => {
    loadContracts();
    loadStats();
  }, [statusFilter]);

  const loadContracts = async () => {
    try {
      let query = supabase
        .from('service_contracts')
        .select(`
          *,
          customers(name, email),
          customer_locations(location_name, address),
          contract_plans(name)
        `);

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;
      setContracts(data || []);
    } catch (error) {
      console.error('Error loading contracts:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadStats = async () => {
    try {
      const { data: activeData, error: activeError } = await supabase
        .from('service_contracts')
        .select('id, base_fee')
        .eq('status', 'active');

      if (activeError) throw activeError;

      const { data: expiringData, error: expiringError } = await supabase
        .from('service_contracts')
        .select('id')
        .eq('status', 'active')
        .gte('end_date', new Date().toISOString().split('T')[0])
        .lte('end_date', new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]);

      if (expiringError) throw expiringError;

      const totalRevenue = (activeData || []).reduce((sum, contract) => sum + Number(contract.base_fee || 0), 0);

      setStats({
        activeContracts: activeData?.length || 0,
        totalRevenue,
        expiringNext30Days: expiringData?.length || 0,
      });
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const filteredContracts = contracts.filter((contract) => {
    const matchesSearch =
      contract.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      contract.customers?.name.toLowerCase().includes(searchTerm.toLowerCase());

    return matchesSearch;
  });

  const getStatusColor = (status: ContractStatus) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400';
      case 'draft':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
      case 'expired':
        return 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400';
      case 'cancelled':
      case 'suspended':
        return 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400';
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400';
    }
  };

  const formatStatus = (status: string) => {
    return status.charAt(0).toUpperCase() + status.slice(1);
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Service Contracts</h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Manage customer maintenance agreements and service plans
          </p>
        </div>
        <button onClick={() => setShowNewModal(true)} className="btn-primary">
          <Plus className="w-5 h-5 mr-2" />
          New Contract
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Active Contracts</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-1">
                {stats.activeContracts}
              </p>
            </div>
            <div className="w-12 h-12 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center">
              <FileText className="w-6 h-6 text-blue-600 dark:text-blue-400" />
            </div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Annual Revenue</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-1">
                {formatCurrency(stats.totalRevenue)}
              </p>
            </div>
            <div className="w-12 h-12 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
              <DollarSign className="w-6 h-6 text-green-600 dark:text-green-400" />
            </div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Expiring in 30 Days</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-1">
                {stats.expiringNext30Days}
              </p>
            </div>
            <div className="w-12 h-12 bg-orange-100 dark:bg-orange-900/30 rounded-lg flex items-center justify-center">
              <TrendingUp className="w-6 h-6 text-orange-600 dark:text-orange-400" />
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-4 sm:space-y-0">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search contracts or customers..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="input pl-10 w-full"
              />
            </div>

            <div className="flex items-center space-x-2">
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="input"
              >
                <option value="all">All Statuses</option>
                <option value="draft">Draft</option>
                <option value="active">Active</option>
                <option value="expired">Expired</option>
                <option value="cancelled">Cancelled</option>
                <option value="suspended">Suspended</option>
              </select>
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>Contract Name</th>
                <th>Customer</th>
                <th>Plan</th>
                <th>Status</th>
                <th>Term</th>
                <th>Next Billing</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredContracts.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12">
                    <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-600 dark:text-gray-400">
                      {searchTerm ? 'No contracts found matching your search' : 'No contracts yet'}
                    </p>
                    {!searchTerm && (
                      <button
                        onClick={() => setShowNewModal(true)}
                        className="btn-primary mt-4"
                      >
                        <Plus className="w-5 h-5 mr-2" />
                        Create First Contract
                      </button>
                    )}
                  </td>
                </tr>
              ) : (
                filteredContracts.map((contract) => (
                  <tr key={contract.id}>
                    <td>
                      <div className="font-medium text-gray-900 dark:text-white">
                        {contract.name}
                      </div>
                      {contract.customer_locations && (
                        <div className="text-sm text-gray-600 dark:text-gray-400">
                          {contract.customer_locations.location_name}
                        </div>
                      )}
                    </td>
                    <td>
                      <div className="text-gray-900 dark:text-white">
                        {contract.customers?.name}
                      </div>
                      <div className="text-sm text-gray-600 dark:text-gray-400">
                        {contract.customers?.email}
                      </div>
                    </td>
                    <td>
                      <span className="badge badge-blue">
                        {contract.contract_plans?.name || 'Custom'}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${getStatusColor(contract.status as ContractStatus)}`}>
                        {formatStatus(contract.status)}
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center text-sm text-gray-600 dark:text-gray-400">
                        <Calendar className="w-4 h-4 mr-1" />
                        {contract.start_date} to {contract.end_date || 'Ongoing'}
                      </div>
                    </td>
                    <td>
                      {contract.next_billing_date ? (
                        <div className="text-sm text-gray-600 dark:text-gray-400">
                          {contract.next_billing_date}
                        </div>
                      ) : (
                        <span className="text-gray-400">-</span>
                      )}
                    </td>
                    <td>
                      <button
                        onClick={() => setSelectedContract(contract)}
                        className="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 text-sm font-medium"
                      >
                        View Details
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {selectedContract && (
        <ContractDetailModal
          contract={selectedContract}
          onClose={() => {
            setSelectedContract(null);
            loadContracts();
            loadStats();
          }}
        />
      )}

      {showNewModal && (
        <NewContractModal
          onClose={() => {
            setShowNewModal(false);
            loadContracts();
            loadStats();
          }}
        />
      )}
    </div>
  );
}
