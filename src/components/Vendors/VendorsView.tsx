import { useEffect, useState } from 'react';
import {
  Building2,
  Search,
  Plus,
  Star,
  AlertCircle,
  CheckCircle,
  Clock,
  XCircle,
  Filter,
} from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { NewVendorModal } from './NewVendorModal';
import { VendorDetailModal } from './VendorDetailModal';
import { VendorContractsView } from './VendorContractsView';

interface Vendor {
  id: string;
  vendor_code: string;
  name: string;
  display_name: string;
  legal_name: string;
  tax_id: string;
  primary_email: string;
  primary_phone: string;
  website: string;
  address_line1: string;
  address_line2: string;
  city: string;
  state: string;
  postal_code: string;
  country: string;
  status: string;
  rating: number | null;
  preferred_vendor: boolean;
  payment_terms: string;
  payment_method: string;
  credit_limit: number | null;
  standard_lead_time_days: number;
  minimum_order_amount: number | null;
  notes: string;
  internal_notes: string;
  created_at: string;
}

interface VendorsViewProps {
  initialTab?: string;
}

export function VendorsView({ initialTab = 'list' }: VendorsViewProps = {}) {
  const { profile } = useAuth();
  const [vendors, setVendors] = useState<Vendor[]>([]);
  const [filteredVendors, setFilteredVendors] = useState<Vendor[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [preferredFilter, setPreferredFilter] = useState<boolean | null>(null);
  const [showNewVendorModal, setShowNewVendorModal] = useState(false);
  const [selectedVendor, setSelectedVendor] = useState<Vendor | null>(null);
  const [activeTab, setActiveTab] = useState(initialTab);

  useEffect(() => {
    loadVendors();
  }, []);

  useEffect(() => {
    filterVendors();
  }, [vendors, searchTerm, statusFilter, preferredFilter]);

  const loadVendors = async () => {
    try {
      const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .order('display_name');

      if (error) throw error;
      setVendors(data || []);
    } catch (error) {
      console.error('Error loading vendors:', error);
    } finally {
      setLoading(false);
    }
  };

  const filterVendors = () => {
    let filtered = vendors;

    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(
        (v) =>
          v.display_name?.toLowerCase().includes(term) ||
          v.vendor_code?.toLowerCase().includes(term) ||
          v.legal_name?.toLowerCase().includes(term) ||
          v.primary_email?.toLowerCase().includes(term)
      );
    }

    if (statusFilter !== 'all') {
      filtered = filtered.filter((v) => v.status === statusFilter);
    }

    if (preferredFilter !== null) {
      filtered = filtered.filter((v) => v.preferred_vendor === preferredFilter);
    }

    setFilteredVendors(filtered);
  };

  const getStatusBadge = (status: string) => {
    const badges: Record<string, { className: string; icon: any }> = {
      active: { className: 'badge badge-green', icon: CheckCircle },
      pending: { className: 'badge badge-yellow', icon: Clock },
      on_hold: { className: 'badge badge-orange', icon: AlertCircle },
      inactive: { className: 'badge badge-gray', icon: XCircle },
      blacklisted: { className: 'badge badge-red', icon: XCircle },
    };
    const config = badges[status] || badges.inactive;
    const Icon = config.icon;
    return (
      <span className={config.className}>
        <Icon className="w-3 h-3 mr-1" />
        {status.replace('_', ' ')}
      </span>
    );
  };

  const getRatingStars = (rating: number | null) => {
    if (!rating) return <span className="text-gray-400 text-sm">No rating</span>;
    return (
      <div className="flex items-center">
        {[...Array(5)].map((_, i) => (
          <Star
            key={i}
            className={`w-4 h-4 ${
              i < Math.floor(rating)
                ? 'fill-yellow-400 text-yellow-400'
                : 'text-gray-300'
            }`}
          />
        ))}
        <span className="ml-1 text-sm text-gray-600 dark:text-gray-400">
          ({rating.toFixed(1)})
        </span>
      </div>
    );
  };

  const stats = {
    total: vendors.length,
    active: vendors.filter((v) => v.status === 'active').length,
    preferred: vendors.filter((v) => v.preferred_vendor).length,
    pending: vendors.filter((v) => v.status === 'pending').length,
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const renderTabContent = () => {
    if (activeTab === 'contracts') {
      return <VendorContractsView showVendorColumn={true} />;
    }

    if (activeTab === 'performance') {
      return (
        <div className="card p-8 text-center">
          <Building2 className="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
            Performance Scores
          </h3>
          <p className="text-gray-600 dark:text-gray-400">
            This feature is coming soon. Track vendor performance metrics and ratings.
          </p>
        </div>
      );
    }

    if (activeTab === 'payments') {
      return (
        <div className="card p-8 text-center">
          <Building2 className="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
            Payment History
          </h3>
          <p className="text-gray-600 dark:text-gray-400">
            This feature is coming soon. View payment history and financial transactions with vendors.
          </p>
        </div>
      );
    }

    return (
      <>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="card p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Total Vendors</p>
                <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                  {stats.total}
                </p>
              </div>
              <div className="bg-blue-100 dark:bg-blue-900/20 text-blue-600 p-3 rounded-lg">
                <Building2 className="w-6 h-6" />
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Active</p>
                <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                  {stats.active}
                </p>
              </div>
              <div className="bg-green-100 dark:bg-green-900/20 text-green-600 p-3 rounded-lg">
                <CheckCircle className="w-6 h-6" />
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Preferred</p>
                <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                  {stats.preferred}
                </p>
              </div>
              <div className="bg-yellow-100 dark:bg-yellow-900/20 text-yellow-600 p-3 rounded-lg">
                <Star className="w-6 h-6" />
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Pending</p>
                <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                  {stats.pending}
                </p>
              </div>
              <div className="bg-orange-100 dark:bg-orange-900/20 text-orange-600 p-3 rounded-lg">
                <Clock className="w-6 h-6" />
              </div>
            </div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex flex-col md:flex-row gap-4 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search vendors by name, code, or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="input pl-10 w-full"
              />
            </div>

            <div className="flex gap-2">
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="input"
              >
                <option value="all">All Statuses</option>
                <option value="active">Active</option>
                <option value="pending">Pending</option>
                <option value="on_hold">On Hold</option>
                <option value="inactive">Inactive</option>
              </select>

              <button
                onClick={() =>
                  setPreferredFilter(preferredFilter === null ? true : null)
                }
                className={`btn ${
                  preferredFilter ? 'btn-primary' : 'btn-secondary'
                }`}
              >
                <Star
                  className={`w-4 h-4 mr-2 ${
                    preferredFilter ? 'fill-current' : ''
                  }`}
                />
                Preferred
              </button>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Vendor Code</th>
                  <th>Name</th>
                  <th>Contact</th>
                  <th>Location</th>
                  <th>Status</th>
                  <th>Rating</th>
                  <th>Payment Terms</th>
                  <th>Lead Time</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredVendors.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="text-center py-8 text-gray-500">
                      No vendors found
                    </td>
                  </tr>
                ) : (
                  filteredVendors.map((vendor) => (
                    <tr key={vendor.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                      <td className="font-medium">
                        <div className="flex items-center">
                          {vendor.vendor_code}
                          {vendor.preferred_vendor && (
                            <Star className="w-4 h-4 ml-2 fill-yellow-400 text-yellow-400" />
                          )}
                        </div>
                      </td>
                      <td>
                        <div>
                          <div className="font-medium text-gray-900 dark:text-white">
                            {vendor.name || vendor.display_name || vendor.legal_name}
                          </div>
                          {vendor.legal_name && vendor.legal_name !== vendor.name && (
                            <div className="text-xs text-gray-500">{vendor.legal_name}</div>
                          )}
                        </div>
                      </td>
                      <td>
                        <div className="text-sm">
                          <div>{vendor.primary_email || '-'}</div>
                          <div className="text-gray-500">{vendor.primary_phone || '-'}</div>
                        </div>
                      </td>
                      <td>
                        {vendor.city && vendor.state
                          ? `${vendor.city}, ${vendor.state}`
                          : '-'}
                      </td>
                      <td>{getStatusBadge(vendor.status)}</td>
                      <td>{getRatingStars(vendor.rating)}</td>
                      <td>{vendor.payment_terms || '-'}</td>
                      <td>{vendor.standard_lead_time_days || 0} days</td>
                      <td>
                        <button
                          onClick={() => setSelectedVendor(vendor)}
                          className="btn btn-sm btn-secondary"
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
      </>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            Vendor Management
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Manage suppliers, contracts, and vendor relationships
          </p>
        </div>
        {(profile?.role === 'admin' || profile?.role === 'dispatcher') && activeTab === 'list' && (
          <button
            onClick={() => setShowNewVendorModal(true)}
            className="btn btn-primary"
          >
            <Plus className="w-5 h-5 mr-2" />
            New Vendor
          </button>
        )}
      </div>

      <div className="border-b border-gray-200 dark:border-gray-700">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('list')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'list'
                ? 'border-blue-500 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400'
            }`}
          >
            Vendor List
          </button>
          <button
            onClick={() => setActiveTab('contracts')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'contracts'
                ? 'border-blue-500 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400'
            }`}
          >
            Contracts & Agreements
          </button>
          <button
            onClick={() => setActiveTab('performance')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'performance'
                ? 'border-blue-500 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400'
            }`}
          >
            Performance Scores
          </button>
          <button
            onClick={() => setActiveTab('payments')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'payments'
                ? 'border-blue-500 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400'
            }`}
          >
            Payment History
          </button>
        </nav>
      </div>

      {renderTabContent()}

      {showNewVendorModal && (
        <NewVendorModal
          onClose={() => setShowNewVendorModal(false)}
          onSuccess={() => {
            loadVendors();
            setShowNewVendorModal(false);
          }}
        />
      )}

      {selectedVendor && (
        <VendorDetailModal
          vendor={selectedVendor}
          onClose={() => setSelectedVendor(null)}
          onUpdate={() => {
            loadVendors();
            setSelectedVendor(null);
          }}
        />
      )}
    </div>
  );
}
