import { useState } from 'react';
import { Users, Building } from 'lucide-react';
import { UserManagement } from './UserManagement';

export function SettingsView() {
  const [activeTab, setActiveTab] = useState<'users' | 'company'>('users');

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Settings</h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Manage system configuration and users
        </p>
      </div>

      <div className="card p-1">
        <div className="flex space-x-1">
          <button
            onClick={() => setActiveTab('users')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-colors flex items-center justify-center space-x-2 ${
              activeTab === 'users'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
            }`}
          >
            <Users className="w-5 h-5" />
            <span>User Management</span>
          </button>
          <button
            onClick={() => setActiveTab('company')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-colors flex items-center justify-center space-x-2 ${
              activeTab === 'company'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
            }`}
          >
            <Building className="w-5 h-5" />
            <span>Company Settings</span>
          </button>
        </div>
      </div>

      {activeTab === 'users' ? (
        <UserManagement />
      ) : (
        <div className="card p-8 text-center">
          <Building className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">
            Company Settings
          </h3>
          <p className="text-gray-600 dark:text-gray-400">
            Company configuration options coming soon
          </p>
        </div>
      )}
    </div>
  );
}
