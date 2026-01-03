import { useState, useEffect } from 'react';
import {
  ChevronDown,
  ChevronRight,
  LogOut,
  Moon,
  Sun,
  Wrench,
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { navigationConfig, NavigationItem, NavigationGroup } from '../../config/navigationConfig';

interface SidebarNewProps {
  currentView: string;
  onViewChange: (view: string) => void;
}

export function SidebarNew({ currentView, onViewChange }: SidebarNewProps) {
  const { profile, signOut } = useAuth();
  const [darkMode, setDarkMode] = useState(() => {
    const saved = localStorage.getItem('darkMode');
    return saved ? JSON.parse(saved) : false;
  });
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(() => {
    const saved = localStorage.getItem('expandedGroups');
    return saved ? new Set(JSON.parse(saved)) : new Set(['field-ops']);
  });

  useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    localStorage.setItem('darkMode', JSON.stringify(darkMode));
  }, [darkMode]);

  useEffect(() => {
    localStorage.setItem('expandedGroups', JSON.stringify([...expandedGroups]));
  }, [expandedGroups]);

  const toggleDarkMode = () => {
    setDarkMode(!darkMode);
  };

  const toggleGroup = (groupId: string, isParentGroup: boolean = false) => {
    setExpandedGroups((prevExpanded) => {
      const newExpanded = new Set(prevExpanded);
      if (newExpanded.has(groupId)) {
        newExpanded.delete(groupId);
      } else {
        if (isParentGroup) {
          navigationConfig.forEach(group => {
            if (group.id !== groupId) {
              newExpanded.delete(group.id);
            }
          });
        }
        newExpanded.add(groupId);
      }
      return newExpanded;
    });
  };

  const hasAccess = (roles: string[]): boolean => {
    return roles.includes(profile?.role || '');
  };

  const filterNavigationByRole = (items: NavigationItem[]): NavigationItem[] => {
    return items
      .filter((item) => hasAccess(item.roles))
      .map((item) => ({
        ...item,
        children: item.children ? filterNavigationByRole(item.children) : undefined,
      }));
  };

  const visibleGroups = navigationConfig
    .filter((group) => hasAccess(group.roles))
    .map((group) => ({
      ...group,
      children: filterNavigationByRole(group.children),
    }))
    .filter((group) => group.children.length > 0);

  const renderMenuItem = (item: NavigationItem, depth: number = 0) => {
    const Icon = item.icon;
    const isActive = currentView === item.id;
    const hasChildren = item.children && item.children.length > 0;
    const isExpanded = expandedGroups.has(item.id);

    const paddingLeft = depth === 0 ? 'pl-4' : depth === 1 ? 'pl-8' : 'pl-12';

    return (
      <div key={item.id}>
        <button
          onClick={() => {
            if (hasChildren) {
              toggleGroup(item.id);
            } else {
              onViewChange(item.id);
            }
          }}
          className={`w-full flex items-center justify-between ${paddingLeft} pr-4 py-2.5 text-sm rounded-lg transition-all ${
            isActive
              ? 'bg-blue-600 text-white font-medium'
              : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
          }`}
        >
          <div className="flex items-center space-x-3">
            <Icon className="w-4 h-4 flex-shrink-0" />
            <span>{item.label}</span>
            {item.badge && (
              <span className="px-2 py-0.5 text-xs rounded-full bg-red-500 text-white">
                {item.badge}
              </span>
            )}
          </div>
          {hasChildren && (
            <div className="flex-shrink-0">
              {isExpanded ? (
                <ChevronDown className="w-4 h-4" />
              ) : (
                <ChevronRight className="w-4 h-4" />
              )}
            </div>
          )}
        </button>

        {hasChildren && isExpanded && (
          <div className="mt-1 space-y-1">
            {item.children?.map((child) => renderMenuItem(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  const renderGroup = (group: NavigationGroup) => {
    const Icon = group.icon;
    const isExpanded = expandedGroups.has(group.id);

    return (
      <div key={group.id} className="mb-1">
        <button
          onClick={() => toggleGroup(group.id, true)}
          className="w-full flex items-center justify-between px-4 py-3 text-sm font-semibold text-gray-900 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-700/50 rounded-lg transition-all"
        >
          <div className="flex items-center space-x-3">
            <Icon className="w-5 h-5 text-blue-600 dark:text-blue-400" />
            <span>{group.label}</span>
          </div>
          {isExpanded ? (
            <ChevronDown className="w-4 h-4 text-gray-500" />
          ) : (
            <ChevronRight className="w-4 h-4 text-gray-500" />
          )}
        </button>

        {isExpanded && (
          <div className="mt-1 space-y-1 pb-2">
            {group.children.map((item) => renderMenuItem(item, 0))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="w-64 bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 flex flex-col h-screen">
      <div className="p-4 sm:p-6 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center justify-center">
          <img
            src="/image.png"
            alt="Dunaway Logo"
            className="h-16 w-auto object-contain"
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-3">
        <nav className="space-y-1">
          {visibleGroups.map((group) => renderGroup(group))}
        </nav>
      </div>

      <div className="border-t border-gray-200 dark:border-gray-700 p-4">
        <div className="mb-4 p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg">
          <p className="text-xs text-gray-600 dark:text-gray-400 mb-1">Logged in as</p>
          <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
            {profile?.full_name}
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-500 capitalize">
            {profile?.role}
          </p>
        </div>

        <div className="space-y-2">
          <button
            onClick={toggleDarkMode}
            className="w-full flex items-center space-x-3 px-4 py-2.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            {darkMode ? (
              <>
                <Sun className="w-4 h-4" />
                <span>Light Mode</span>
              </>
            ) : (
              <>
                <Moon className="w-4 h-4" />
                <span>Dark Mode</span>
              </>
            )}
          </button>

          <button
            onClick={signOut}
            className="w-full flex items-center space-x-3 px-4 py-2.5 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>
    </div>
  );
}
