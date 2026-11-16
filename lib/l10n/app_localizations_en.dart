// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Milk HUB';

  @override
  String get admin => 'Admin';

  @override
  String get seller => 'Seller';

  @override
  String get customer => 'Customer';

  @override
  String get customers => 'Customers';

  @override
  String get doodhwala => 'Milkman (Doodhwala)';

  @override
  String get deliveryBoy => 'Delivery Boy';

  @override
  String get soloMilkman => 'Solo Milkman';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get confirm => 'Confirm';

  @override
  String get search => 'Search';

  @override
  String get refresh => 'Refresh';

  @override
  String get back => 'Back';

  @override
  String get submit => 'Submit';

  @override
  String get done => 'Done';

  @override
  String get settings => 'Settings';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get shift => 'Shift';

  @override
  String get morningShift => 'Morning';

  @override
  String get eveningShift => 'Evening';

  @override
  String get bothShifts => 'Both Shifts';

  @override
  String get cowMilk => 'Cow Milk';

  @override
  String get buffaloMilk => 'Buffalo Milk';

  @override
  String get mixedMilk => 'Mixed Milk';

  @override
  String get ratePerLiter => 'Rate per Liter';

  @override
  String get quantity => 'Quantity';

  @override
  String get liters => 'Liters';

  @override
  String get milliliters => 'Milliliters';

  @override
  String get delivered => '✔ Delivered';

  @override
  String get notDeliveredToday => '✕ Skipped Today';

  @override
  String get skipped => 'Skipped';

  @override
  String get pausedVacation => '⛔ Milk Paused (Vacation)';

  @override
  String get vacation => 'Vacation';

  @override
  String get deliveryEntry => 'Delivery Entry';

  @override
  String get route => 'Route';

  @override
  String get routes => 'Routes';

  @override
  String get stopSequence => 'Stop Sequence';

  @override
  String get customerSequence => 'Customer Sequence';

  @override
  String get routeCustomers => 'Route Customers';

  @override
  String get reorderStops => 'Reorder Stops';

  @override
  String get addRoute => 'Add Route';

  @override
  String get editRoute => 'Edit Route';

  @override
  String get deleteRoute => 'Delete Route';

  @override
  String get routeName => 'Route Name';

  @override
  String get payViaUpi => 'Pay via UPI';

  @override
  String get scanQrToPay => 'Scan QR Code to Pay';

  @override
  String get cashCollected => 'Cash Collected';

  @override
  String get doorstepCashCollected => 'Doorstep Cash Collected';

  @override
  String get shareInvoiceWhatsapp => 'Share Invoice on WhatsApp';

  @override
  String get monthlyBill => 'Monthly Bill';

  @override
  String get totalLiters => 'Total Liters';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get pendingAmount => 'Pending Amount';

  @override
  String get paidAmount => 'Paid Amount';

  @override
  String get monthlySummary => 'Monthly Summary';

  @override
  String get recordCollection => 'Record Collection';

  @override
  String get pauseMilk => 'Pause Milk Delivery';

  @override
  String get pauseRequest => 'Pause Request';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get reason => 'Reason';

  @override
  String get pendingApprovals => 'Pending Approvals';

  @override
  String get approvePause => 'Approve Pause';

  @override
  String get rejectPause => 'Reject Pause';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get hindiLanguage => 'Hindi (हिंदी)';

  @override
  String get englishLanguage => 'English';

  @override
  String get switchLanguage => 'Switch Language';

  @override
  String get switchLanguageSubtitle => 'Switch app language / ऐप की भाषा बदलें';

  @override
  String get keepScreenAwake => 'Keep Screen Awake';

  @override
  String get logout => 'Logout';

  @override
  String get logoutSubtitle => 'Ends session and clears Remember Me';

  @override
  String welcomeUser(String userName) {
    return 'Welcome, $userName';
  }

  @override
  String stopSequenceBadge(int sequence) {
    return 'Stop #$sequence';
  }

  @override
  String formatRupees(String amount) {
    return '₹$amount';
  }

  @override
  String formatLiters(String liters) {
    return '$liters L';
  }

  @override
  String get allShifts => 'All Shifts';

  @override
  String get manageRoutes => 'Manage Routes';

  @override
  String get noRoutesFound => 'No delivery routes found';

  @override
  String get createFirstRoute =>
      'Create your first route to organize deliveries';

  @override
  String get routeDescription => 'Description (Optional)';

  @override
  String get assignedSeller => 'Assigned Seller';

  @override
  String get selectSeller => 'Select Seller';

  @override
  String get noSellerAssigned => 'No seller assigned (Owner Delivery)';

  @override
  String get unassigned => 'Unassigned';

  @override
  String customerCountBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Customers',
      one: '1 Customer',
      zero: 'No customers',
    );
    return '$_temp0';
  }

  @override
  String get deleteRouteConfirmTitle => 'Delete Route';

  @override
  String get deleteRouteConfirmMessage =>
      'Are you sure you want to delete this route? Customer sequence assignments will be reset.';

  @override
  String get sequenceUpdated =>
      'Customer delivery sequence updated successfully';

  @override
  String get routeSaved => 'Route saved successfully';

  @override
  String get routeDeleted => 'Route deleted successfully';

  @override
  String get saveSequence => 'Save Sequence';

  @override
  String get dragToReorder => 'Drag handles to reorder delivery stops';

  @override
  String get selectRoute => 'Select Route';

  @override
  String get allRoutes => 'All Routes';

  @override
  String get activeRoute => 'Active Route';

  @override
  String get noRoutesAssigned => 'No routes assigned yet';

  @override
  String get startDelivery => 'Start Delivery';

  @override
  String get viewCustomers => 'View Customers';

  @override
  String get todaysInventory => 'Today\'s Inventory';

  @override
  String get assigned => 'Assigned';

  @override
  String get soldToday => 'Sold Today';

  @override
  String get remaining => 'Remaining';

  @override
  String get collectionSnapshot => 'Collection Snapshot';

  @override
  String get billed => 'Billed';

  @override
  String get collected => 'Collected';

  @override
  String get deliveryReminder => 'Delivery Reminder';

  @override
  String get stockRefill => 'Stock Refill';

  @override
  String get openCalendar => 'Open Calendar';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get sellerNotFound =>
      'Seller record not found.\nPlease contact admin.';

  @override
  String get noCustomersOnRoute => 'No customers on this route';

  @override
  String get ownerDelivery => 'Owner-Seller Delivery';

  @override
  String get deliverRoute => 'Deliver Route';

  @override
  String get quickDeliver => 'Deliver Now';
}
