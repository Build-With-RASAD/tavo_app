// lib/feature/booking/data/model/booking_model.dart
import 'package:tavo/feature/booking/data/model/booking_status.dart';
import 'package:tavo/feature/booking/data/model/order_details_model.dart';

class BookingModel {
  final String id;
  final String restaurantId;
  final String restaurantNameAr;
  final String restaurantNameEn;
  final String restaurantLogoUrl;
  final String restaurantAddress;
  final DateTime startAt;
  final DateTime endAt;
  final int guestsCount;
  final String status;
  final List<TableModel> tables;
  final OrderData? order;
  final String specialRequests;
  final String tablePreference;
  final String createdAt;

  /// Staff view only: who made the reservation. Populated backends send the
  /// guest as `userId: {name, phone}`; guest (walk-up) bookings send
  /// `customer: {name, phone}`. Empty for legacy payloads.
  final String guestName;
  final String guestPhone;

  const BookingModel({
    required this.id,
    this.restaurantId = '',
    this.restaurantNameAr = '',
    this.restaurantNameEn = '',
    this.restaurantLogoUrl = '',
    this.restaurantAddress = '',
    required this.startAt,
    required this.endAt,
    this.guestsCount = 1,
    this.status = 'pending',
    this.tables = const [],
    this.order,
    this.specialRequests = '',
    this.tablePreference = 'any',
    required this.createdAt,
    this.guestName = '',
    this.guestPhone = '',
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurantId'];
    String nameAr = '';
    String nameEn = '';
    String logoUrl = '';
    String restId = '';
    String address = '';

    if (restaurant is Map<String, dynamic>) {
      restId = restaurant['_id'] ?? '';
      nameAr = restaurant['ar']?['name'] ?? '';
      nameEn = restaurant['en']?['name'] ?? '';
      logoUrl = restaurant['logo']?['imageUrl'] ?? '';
      address = restaurant['address'] ?? '';
    }

    final tables =
        (json['physicalTableIds'] as List<dynamic>?)?.map((e) {
          if (e is String) {
            return TableModel(id: e);
          } else if (e is Map<String, dynamic>) {
            return TableModel.fromJson(e);
          }
          return TableModel();
        }).toList() ??
        [];

    OrderData? orderData;
    if (json['orderId'] is Map<String, dynamic>) {
      orderData = OrderData.fromJson(json['orderId']);
    }

    // Guest identity: prefer the populated user, fall back to the embedded
    // guest customer, otherwise leave empty (customer own-booking payloads).
    String guestName = '';
    String guestPhone = '';
    final user = json['userId'];
    if (user is Map<String, dynamic>) {
      guestName = user['name']?.toString() ?? '';
      guestPhone = user['phone']?.toString() ?? '';
    }
    if (guestName.isEmpty && guestPhone.isEmpty) {
      final customer = json['customer'];
      if (customer is Map<String, dynamic>) {
        guestName = customer['name']?.toString() ?? '';
        guestPhone = customer['phone']?.toString() ?? '';
      }
    }

    return BookingModel(
      id: json['_id'] ?? '',
      restaurantId: restId,
      restaurantNameAr: nameAr,
      restaurantNameEn: nameEn,
      restaurantLogoUrl: logoUrl,
      restaurantAddress: address,
      startAt: DateTime.parse(
        json['startAt'] ?? DateTime.now().toIso8601String(),
      ),
      endAt: DateTime.parse(json['endAt'] ?? DateTime.now().toIso8601String()),
      guestsCount: json['guestsCount'] ?? 1,
      status: json['status'] ?? 'pending',
      tables: tables,
      order: orderData,
      specialRequests: json['specialRequests'] ?? '',
      tablePreference: json['tablePreference'] ?? 'any',
      createdAt: json['createdAt'] ?? '',
      guestName: guestName,
      guestPhone: guestPhone,
    );
  }

  String getName(String locale) {
    if (locale == 'ar') return restaurantNameAr;
    return restaurantNameEn.isNotEmpty ? restaurantNameEn : restaurantNameAr;
  }

  String getFormattedDate(String locale) {
    final monthsAr = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final monthsEn = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final months = locale == 'ar' ? monthsAr : monthsEn;
    final hour = startAt.hour > 12
        ? startAt.hour - 12
        : (startAt.hour == 0 ? 12 : startAt.hour);
    final period = startAt.hour >= 12
        ? (locale == 'ar' ? 'م' : 'PM')
        : (locale == 'ar' ? 'ص' : 'AM');
    final minute = startAt.minute.toString().padLeft(2, '0');

    return '${startAt.day} ${months[startAt.month]} ${startAt.year} - $hour:$minute $period';
  }

  String getFormattedTime(String locale) {
    final hour = startAt.hour > 12
        ? startAt.hour - 12
        : (startAt.hour == 0 ? 12 : startAt.hour);
    final period = startAt.hour >= 12
        ? (locale == 'ar' ? 'م' : 'PM')
        : (locale == 'ar' ? 'ص' : 'AM');
    final minute = startAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String getTimeRange(String locale) {
    final startHour = startAt.hour > 12
        ? startAt.hour - 12
        : (startAt.hour == 0 ? 12 : startAt.hour);
    final endHour = endAt.hour > 12
        ? endAt.hour - 12
        : (endAt.hour == 0 ? 12 : endAt.hour);
    final startPeriod = startAt.hour >= 12
        ? (locale == 'ar' ? 'م' : 'PM')
        : (locale == 'ar' ? 'ص' : 'AM');
    final endPeriod = endAt.hour >= 12
        ? (locale == 'ar' ? 'م' : 'PM')
        : (locale == 'ar' ? 'ص' : 'AM');
    final startMin = startAt.minute.toString().padLeft(2, '0');
    final endMin = endAt.minute.toString().padLeft(2, '0');
    return '$startHour:$startMin $startPeriod - $endHour:$endMin $endPeriod';
  }

  String getTablesText() {
    if (tables.isEmpty) return '';
    return tables.map((t) => t.code).join(', ');
  }

  BookingStatus get bookingStatus {
    switch (status) {
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
      case 'no_show':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.inProgress;
    }
  }

  String getStatusText(String locale) {
    if (locale == 'ar') {
      switch (status) {
        case 'pending':
          return 'قيد التأكيد';
        case 'confirmed':
          return 'مؤكد';
        case 'seated':
          return 'جالس';
        case 'finished_meal':
          return 'انتهى الطعام';
        case 'completed':
          return 'مكتمل';
        case 'cancelled':
          return 'ملغي';
        case 'no_show':
          return 'لم يحضر';
        default:
          return status;
      }
    }
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'seated':
        return 'Seated';
      case 'finished_meal':
        return 'Finished';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      default:
        return status;
    }
  }
}

class TableModel {
  final String id;
  final String code;
  final int seats;

  const TableModel({this.id = '', this.code = '', this.seats = 0});

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['_id'] ?? '',
      code: json['code'] ?? '',
      seats: json['seats'] ?? 0,
    );
  }
}

class OrderData {
  final String id;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double tax;
  final double totalPrice;
  final List<OrderMenuShort> menuItems;
  final String createdAt;

  const OrderData({
    this.id = '',
    this.orderNumber = '',
    this.status = '',
    this.subtotal = 0,
    this.tax = 0,
    this.totalPrice = 0,
    this.menuItems = const [],
    this.createdAt = '',
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      status: json['orderStatus'] ?? 'draft',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      menuItems:
          (json['menuItems'] as List<dynamic>?)
              ?.map((e) => OrderMenuShort.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class OrderMenuShort {
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<OrderSpecification> specifications;

  const OrderMenuShort({
    this.name = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.specifications = const [],
  });

  factory OrderMenuShort.fromJson(Map<String, dynamic> json) {
    return OrderMenuShort(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      lineTotal: (json['lineTotal'] ?? 0).toDouble(),
      specifications:
          (json['specifications'] as List<dynamic>?)
              ?.map((e) => OrderSpecification.fromJson(e))
              .toList() ??
          [],
    );
  }
}
