import 'package:flutter/material.dart';
import '../../../core/design/app_icons.dart';

/// The four things the + button can add.
enum EntryType {
  expense('Expense', AppIcons.northEastRounded),
  income('Income', AppIcons.southWestRounded),
  transfer('Transfer', AppIcons.swapHorizRounded),
  goal('Goal', AppIcons.flagRounded);

  const EntryType(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A category with optional subcategories.
@immutable
class CategoryOption {
  const CategoryOption(this.name, this.emoji, [this.subcategories = const []]);
  final String name;
  final String emoji;
  final List<String> subcategories;

  /// Names are unique within a kind, so they identify a category.
  @override
  bool operator ==(Object other) =>
      other is CategoryOption && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Default categories, seeded into the user's list on first launch.
/// Screens read the user's list from `categoriesProvider` instead.
const expenseCategories = [
  CategoryOption('Home', '🏠', [
    'Rent',
    'Electricity',
    'Water',
    'Gas',
    'Appliances',
    'Society Maintenance',
    'Cleaning',
    'Repairs',
    'Furniture',
    'Decorations',
    'Pet',
  ]),
  CategoryOption('Food', '🍔', [
    'Grocery',
    'Restaurant',
    'Snacks',
    'Party',
    'Drinks',
    'Fruits',
    'Tea/Coffee',
    'Milk',
    'Bakery',
  ]),
  CategoryOption('Travel', '🚗', [
    'Petrol',
    'Diesel',
    'Train',
    'Cab',
    'Bus',
    'Flight',
    'Metro',
    'Toll',
    'Parking',
    'Hotel',
  ]),
  CategoryOption('Entertainment', '🎬', [
    'OTT',
    'Movies',
    'Games',
    'Music',
    'Events',
    'Sports',
    'Subscription',
  ]),
  CategoryOption('Shopping', '🛍️', [
    'Clothes',
    'Electronics',
    'Kitchen',
    'Home Accessories',
    'Gadgets',
    'Shoes',
    'Bags',
    'Watches',
    'Jewellery',
    'Gifts',
  ]),
  CategoryOption('Bills', '🧾', [
    'Internet',
    'Mobile',
    'Credit Card',
    'EMI',
    'Subscription',
  ]),
  CategoryOption('Investment', '📈', [
    'SIP',
    'Mutual Fund',
    'Stocks',
    'Gold',
    'PPF',
    'NPS',
    'Fixed Deposit',
    'Recurring Deposit',
    'Crypto',
    'Savings',
    'Emergency Fund',
  ]),
  CategoryOption('Health', '💊', [
    'Doctor',
    'Medicines',
    'Tests',
    'Hospital',
    'Insurance',
    'Dental',
    'Eye Care',
    'Physiotherapy',
    'Supplements',
  ]),
  CategoryOption('Personal', '💆', [
    'Haircut',
    'Gym',
    'Salon',
    'Cosmetics',
    'Skincare',
    'Perfume',
    'Accessories',
  ]),
  CategoryOption('Education', '📚', [
    'Course',
    'Books',
    'Certification',
    'Exam Fees',
    'Coaching',
    'Online Learning',
    'School Fee',
    'College Fee',
  ]),
];

const incomeCategories = [
  CategoryOption('Salary', '💼', ['Monthly salary', 'Bonus']),
  CategoryOption('Freelance', '🧑‍💻', ['Project', 'Hourly']),
  CategoryOption('Business', '🏪'),
  CategoryOption('Investments', '📈', [
    'Interest',
    'Dividends',
    'Capital gains',
  ]),
  CategoryOption('Rental', '🏘️'),
  CategoryOption('Gift', '🎁'),
  CategoryOption('Refund', '↩️'),
  CategoryOption('Other', '💰'),
];

const paymentMethods = [
  'UPI',
  'Cash',
  'Debit card',
  'Credit card',
  'Net banking',
  'Wallet',
];

/// Places money can move between. TODO(phase 3): user-defined accounts.
const accounts = [
  'Cash',
  'Bank account',
  'Savings account',
  'Credit card',
  'Wallet',
];

const paymentMethodIcons = <String, IconData>{
  'UPI': AppIcons.qrCode2Rounded,
  'Cash': AppIcons.paymentsOutlined,
  'Debit card': AppIcons.creditCardRounded,
  'Credit card': AppIcons.creditScoreRounded,
  'Net banking': AppIcons.accountBalanceOutlined,
  'Wallet': AppIcons.accountBalanceWalletOutlined,
};

const accountIcons = <String, IconData>{
  'Cash': AppIcons.paymentsOutlined,
  'Bank account': AppIcons.accountBalanceOutlined,
  'Savings account': AppIcons.savingsOutlined,
  'Credit card': AppIcons.creditCardRounded,
  'Wallet': AppIcons.accountBalanceWalletOutlined,
};
