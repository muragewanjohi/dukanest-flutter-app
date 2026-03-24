import 'package:flutter/material.dart';

class DemoOrder {
  final String id;
  final String customer;
  final String total;
  final String status;
  final String time;

  const DemoOrder({
    required this.id,
    required this.customer,
    required this.total,
    required this.status,
    required this.time,
  });
}

class DemoProduct {
  final String name;
  final String sku;
  final String price;
  final int stock;
  final String category;

  const DemoProduct({
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.category,
  });
}

class DemoCustomer {
  final String name;
  final String email;
  final int orderCount;
  final String lastOrder;
  final String totalSpent;

  const DemoCustomer({
    required this.name,
    required this.email,
    required this.orderCount,
    required this.lastOrder,
    required this.totalSpent,
  });
}

class DemoKpi {
  final String label;
  final String value;
  final String delta;

  const DemoKpi({
    required this.label,
    required this.value,
    required this.delta,
  });
}

class DemoNotification {
  final String title;
  final String message;
  final String time;
  final bool isUnread;
  final IconData icon;

  const DemoNotification({
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.icon,
  });
}

const demoKpis = <DemoKpi>[
  DemoKpi(label: 'Today Sales', value: 'KES 24,500', delta: '+12%'),
  DemoKpi(label: 'Orders', value: '18', delta: '+4'),
  DemoKpi(label: 'Customers', value: '72', delta: '+9'),
  DemoKpi(label: 'Low Stock', value: '6 items', delta: '-2'),
];

const demoWeeklySales = <double>[2.1, 3.4, 2.8, 4.2, 5.1, 4.6, 6.0];

const demoNotifications = <DemoNotification>[
  DemoNotification(
    title: 'New order received',
    message: 'Order #ORD-1048 from Jane Wambui',
    time: '2 min ago',
    isUnread: true,
    icon:  Icons.shopping_bag_outlined,
  ),
  DemoNotification(
    title: 'Low stock alert',
    message: 'Laundry Detergent is below threshold',
    time: '20 min ago',
    isUnread: true,
    icon: Icons.warning_amber_outlined,
  ),
  DemoNotification(
    title: 'Daily sales summary',
    message: 'You made KES 24,500 today',
    time: '1 hr ago',
    isUnread: false,
    icon: Icons.bar_chart_outlined,
  ),
];

const demoOrders = <DemoOrder>[
  DemoOrder(id: '#ORD-1048', customer: 'Jane Wambui', total: 'KES 3,450', status: 'Pending', time: '2 min ago'),
  DemoOrder(id: '#ORD-1047', customer: 'Omondi Kevin', total: 'KES 9,200', status: 'Paid', time: '15 min ago'),
  DemoOrder(id: '#ORD-1046', customer: 'Grace Nyaga', total: 'KES 1,300', status: 'Packed', time: '38 min ago'),
  DemoOrder(id: '#ORD-1045', customer: 'Samuel Kiptoo', total: 'KES 4,900', status: 'Delivered', time: '1 hr ago'),
  DemoOrder(id: '#ORD-1044', customer: 'Miriam Akinyi', total: 'KES 2,100', status: 'Paid', time: '2 hrs ago'),
  DemoOrder(id: '#ORD-1043', customer: 'Faith Kendi', total: 'KES 5,700', status: 'Pending', time: '3 hrs ago'),
];

const demoProducts = <DemoProduct>[
  DemoProduct(name: 'Premium Rice 2kg', sku: 'SKU-001', price: 'KES 420', stock: 18, category: 'Groceries'),
  DemoProduct(name: 'Sunflower Oil 1L', sku: 'SKU-002', price: 'KES 350', stock: 42, category: 'Groceries'),
  DemoProduct(name: 'Laundry Detergent', sku: 'SKU-003', price: 'KES 780', stock: 9, category: 'Home Care'),
  DemoProduct(name: 'Whole Wheat Flour', sku: 'SKU-004', price: 'KES 260', stock: 27, category: 'Groceries'),
  DemoProduct(name: 'Bathing Soap 175g', sku: 'SKU-005', price: 'KES 120', stock: 64, category: 'Personal Care'),
  DemoProduct(name: 'Toothpaste 140ml', sku: 'SKU-006', price: 'KES 210', stock: 12, category: 'Personal Care'),
  DemoProduct(name: 'Soda 500ml', sku: 'SKU-007', price: 'KES 80', stock: 120, category: 'Beverages'),
];

const demoCustomers = <DemoCustomer>[
  DemoCustomer(name: 'Jane Wambui', email: 'jane.wambui@email.com', orderCount: 8, lastOrder: 'Today', totalSpent: 'KES 28,900'),
  DemoCustomer(name: 'Omondi Kevin', email: 'kevin.omondi@email.com', orderCount: 14, lastOrder: 'Yesterday', totalSpent: 'KES 52,100'),
  DemoCustomer(name: 'Grace Nyaga', email: 'g.nyaga@email.com', orderCount: 5, lastOrder: '3 days ago', totalSpent: 'KES 9,400'),
  DemoCustomer(name: 'Samuel Kiptoo', email: 's.kiptoo@email.com', orderCount: 22, lastOrder: '1 week ago', totalSpent: 'KES 81,200'),
  DemoCustomer(name: 'Miriam Akinyi', email: 'miriam.akinyi@email.com', orderCount: 3, lastOrder: '2 days ago', totalSpent: 'KES 6,750'),
  DemoCustomer(name: 'Faith Kendi', email: 'faith.kendi@email.com', orderCount: 11, lastOrder: 'Today', totalSpent: 'KES 34,300'),
  DemoCustomer(name: 'Sarah Jenkins', email: 'sarah.j@email.com', orderCount: 6, lastOrder: 'Oct 24', totalSpent: 'KES 18,400'),
  DemoCustomer(name: 'Marcus Thorne', email: 'marcus.thorne@email.com', orderCount: 19, lastOrder: 'Oct 24', totalSpent: 'KES 63,050'),
];
