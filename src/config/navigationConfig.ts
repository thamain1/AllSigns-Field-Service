import {
  LayoutDashboard,
  Ticket,
  ClipboardList,
  Calendar,
  MapPin,
  Map,
  Clock,
  Package,
  ShoppingCart,
  ArrowLeftRight,
  FileCheck,
  Wrench,
  Settings as SettingsIcon,
  Shield,
  FolderKanban,
  BarChart2,
  DollarSign,
  Users,
  Building2,
  FileText,
  TrendingUp,
  Receipt,
  Calculator,
  Wallet,
  AlertTriangle,
  LineChart,
  PieChart,
  Settings,
  UserCog,
  Bell,
  PackageCheck,
  Upload,
  LucideIcon,
} from 'lucide-react';

export interface NavigationItem {
  id: string;
  label: string;
  icon: LucideIcon;
  roles: string[];
  children?: NavigationItem[];
  badge?: string;
}

export interface NavigationGroup {
  id: string;
  label: string;
  icon: LucideIcon;
  roles: string[];
  children: NavigationItem[];
}

export const navigationConfig: NavigationGroup[] = [
  {
    id: 'field-ops',
    label: 'Field Operations',
    icon: Wrench,
    roles: ['admin', 'dispatcher', 'technician'],
    children: [
      {
        id: 'dashboard',
        label: 'Dashboard',
        icon: LayoutDashboard,
        roles: ['admin', 'dispatcher', 'technician'],
      },
      {
        id: 'tickets',
        label: 'Tickets',
        icon: Ticket,
        roles: ['admin', 'dispatcher', 'technician'],
      },
      {
        id: 'estimates',
        label: 'Estimates',
        icon: ClipboardList,
        roles: ['admin', 'dispatcher', 'technician'],
      },
      {
        id: 'dispatch',
        label: 'Dispatch',
        icon: Calendar,
        roles: ['admin', 'dispatcher'],
      },
      {
        id: 'tracking',
        label: 'Tech Tracking',
        icon: MapPin,
        roles: ['admin', 'dispatcher'],
      },
      {
        id: 'mapping',
        label: 'Call Map',
        icon: Map,
        roles: ['admin', 'dispatcher'],
      },
      {
        id: 'timeclock',
        label: 'Time Clock',
        icon: Clock,
        roles: ['admin', 'dispatcher', 'technician'],
      },
    ],
  },
  {
    id: 'service-assets',
    label: 'Service Assets',
    icon: Package,
    roles: ['admin', 'dispatcher', 'technician'],
    children: [
      {
        id: 'parts',
        label: 'Parts',
        icon: Package,
        roles: ['admin', 'dispatcher', 'technician'],
        children: [
          {
            id: 'parts-inventory',
            label: 'Stock Levels',
            icon: Package,
            roles: ['admin', 'dispatcher', 'technician'],
          },
          {
            id: 'parts-purchase-orders',
            label: 'Purchase Orders',
            icon: ShoppingCart,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'parts-transfers',
            label: 'Transfers',
            icon: ArrowLeftRight,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'parts-receiving',
            label: 'Receiving',
            icon: PackageCheck,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
      {
        id: 'equipment',
        label: 'Equipment',
        icon: Wrench,
        roles: ['admin', 'dispatcher', 'technician'],
        children: [
          {
            id: 'equipment-installed',
            label: 'Installed Equipment',
            icon: SettingsIcon,
            roles: ['admin', 'dispatcher', 'technician'],
          },
          {
            id: 'equipment-parts',
            label: 'Installed Parts',
            icon: Package,
            roles: ['admin', 'dispatcher', 'technician'],
          },
          {
            id: 'equipment-warranty',
            label: 'Warranty Tracking',
            icon: Shield,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
    ],
  },
  {
    id: 'projects',
    label: 'Projects',
    icon: FolderKanban,
    roles: ['admin', 'dispatcher'],
    children: [
      {
        id: 'projects',
        label: 'Project Overview',
        icon: FolderKanban,
        roles: ['admin', 'dispatcher'],
      },
    ],
  },
  {
    id: 'customers',
    label: 'Customers',
    icon: Users,
    roles: ['admin', 'dispatcher', 'technician'],
    children: [
      {
        id: 'customers',
        label: 'Customer Profiles',
        icon: Users,
        roles: ['admin', 'dispatcher', 'technician'],
      },
      {
        id: 'service-contracts',
        label: 'Service Contracts',
        icon: FileText,
        roles: ['admin', 'dispatcher'],
      },
    ],
  },
  {
    id: 'finance',
    label: 'Finance',
    icon: DollarSign,
    roles: ['admin', 'dispatcher'],
    children: [
      {
        id: 'invoicing',
        label: 'Invoicing',
        icon: Receipt,
        roles: ['admin', 'dispatcher'],
      },
      {
        id: 'accounting',
        label: 'Accounting',
        icon: Calculator,
        roles: ['admin', 'dispatcher'],
        children: [
          {
            id: 'accounting-ledger',
            label: 'General Ledger',
            icon: FileText,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'accounting-ar-ap',
            label: 'AR / AP',
            icon: Wallet,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'accounting-chart',
            label: 'Chart of Accounts',
            icon: BarChart2,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'accounting-reconciliation',
            label: 'Reconciliations',
            icon: FileCheck,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
      {
        id: 'payroll',
        label: 'Payroll',
        icon: Wallet,
        roles: ['admin'],
        children: [
          {
            id: 'payroll-runs',
            label: 'Payroll Runs',
            icon: Calculator,
            roles: ['admin'],
          },
          {
            id: 'payroll-time-cost',
            label: 'Time Cost Reports',
            icon: Clock,
            roles: ['admin'],
          },
          {
            id: 'payroll-stubs',
            label: 'Pay Stubs',
            icon: FileText,
            roles: ['admin'],
          },
        ],
      },
    ],
  },
  {
    id: 'procurement',
    label: 'Procurement',
    icon: Building2,
    roles: ['admin', 'dispatcher'],
    children: [
      {
        id: 'vendors',
        label: 'Vendors',
        icon: Building2,
        roles: ['admin', 'dispatcher'],
        children: [
          {
            id: 'vendors-list',
            label: 'Vendor List',
            icon: Building2,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'vendors-contracts',
            label: 'Contracts & Agreements',
            icon: FileText,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'vendors-performance',
            label: 'Performance Scores',
            icon: TrendingUp,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'vendors-payments',
            label: 'Payment History',
            icon: Receipt,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
      {
        id: 'parts-ordering',
        label: 'Parts Ordering',
        icon: ShoppingCart,
        roles: ['admin', 'dispatcher'],
        children: [
          {
            id: 'parts-ordering-catalogs',
            label: 'Vendor Catalogs',
            icon: Package,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'parts-ordering-reorder',
            label: 'Reorder Alerts',
            icon: AlertTriangle,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'parts-ordering-leadtime',
            label: 'Lead Time Reports',
            icon: Clock,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
    ],
  },
  {
    id: 'business-intelligence',
    label: 'Business Intelligence',
    icon: LineChart,
    roles: ['admin', 'dispatcher'],
    children: [
      {
        id: 'reports',
        label: 'Reports',
        icon: BarChart2,
        roles: ['admin', 'dispatcher'],
        children: [
          {
            id: 'reports-job-cost',
            label: 'Job Cost Reports',
            icon: DollarSign,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'reports-financials',
            label: 'Financials',
            icon: Calculator,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'reports-technician',
            label: 'Technician Metrics',
            icon: Users,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'reports-margins',
            label: 'Project Margins',
            icon: TrendingUp,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
      {
        id: 'insights',
        label: 'Insights',
        icon: PieChart,
        roles: ['admin', 'dispatcher'],
        children: [
          {
            id: 'insights-revenue',
            label: 'Revenue Trends',
            icon: TrendingUp,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'insights-customer',
            label: 'Customer Value',
            icon: Users,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'insights-dso',
            label: 'DSO',
            icon: Clock,
            roles: ['admin', 'dispatcher'],
          },
          {
            id: 'insights-labor',
            label: 'Labor Efficiency',
            icon: Wrench,
            roles: ['admin', 'dispatcher'],
          },
        ],
      },
    ],
  },
  {
    id: 'administration',
    label: 'Administration',
    icon: Settings,
    roles: ['admin'],
    children: [
      {
        id: 'data-import',
        label: 'Data Import',
        icon: Upload,
        roles: ['admin'],
      },
      {
        id: 'settings',
        label: 'Settings',
        icon: Settings,
        roles: ['admin'],
        children: [
          {
            id: 'settings-users',
            label: 'User & Role Management',
            icon: UserCog,
            roles: ['admin'],
          },
          {
            id: 'settings-labor-rates',
            label: 'Labor Rate Profiles',
            icon: DollarSign,
            roles: ['admin'],
          },
          {
            id: 'settings-contract-plans',
            label: 'Contract Plans',
            icon: FileText,
            roles: ['admin'],
          },
          {
            id: 'settings-notifications',
            label: 'Notifications & Automation',
            icon: Bell,
            roles: ['admin'],
          },
          {
            id: 'settings-permissions',
            label: 'Permissions',
            icon: Shield,
            roles: ['admin'],
          },
        ],
      },
    ],
  },
];
