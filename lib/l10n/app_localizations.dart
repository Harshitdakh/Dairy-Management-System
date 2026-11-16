import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// Application title displayed in headers and app bar
  ///
  /// In en, this message translates to:
  /// **'Milk HUB'**
  String get appTitle;

  /// Role label for dairy business administrator
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// Role label for milk seller or distributor
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get seller;

  /// Role label for household milk customer
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// Plural section title for customer management
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// Vernacular role title for solo milk delivery operator
  ///
  /// In en, this message translates to:
  /// **'Milkman (Doodhwala)'**
  String get doodhwala;

  /// Role label for delivery assistant
  ///
  /// In en, this message translates to:
  /// **'Delivery Boy'**
  String get deliveryBoy;

  /// Unified Owner-Seller persona title for self-delivering owners
  ///
  /// In en, this message translates to:
  /// **'Solo Milkman'**
  String get soloMilkman;

  /// Action button to save form data
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Action button to dismiss dialog or cancel operation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Destructive action button to remove an entity
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Action button to modify an existing item
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Action button to add a new record
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Action button to confirm an action in a modal
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Search input hint or action
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Action to reload list or screen data
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Navigation action to return to previous screen
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Action button to submit form or request
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Action button indicating task completion
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// App settings navigation title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Status badge for awaiting approval or review
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Status badge for confirmed and approved item
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// Status badge for declined or rejected item
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// Status badge for active entity
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Status badge for inactive entity
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// Delivery shift label
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shift;

  /// Morning delivery shift option
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morningShift;

  /// Evening delivery shift option
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get eveningShift;

  /// Option covering both morning and evening delivery shifts
  ///
  /// In en, this message translates to:
  /// **'Both Shifts'**
  String get bothShifts;

  /// Milk variety: Cow Milk
  ///
  /// In en, this message translates to:
  /// **'Cow Milk'**
  String get cowMilk;

  /// Milk variety: Buffalo Milk
  ///
  /// In en, this message translates to:
  /// **'Buffalo Milk'**
  String get buffaloMilk;

  /// Milk variety: Mixed Cow and Buffalo Milk
  ///
  /// In en, this message translates to:
  /// **'Mixed Milk'**
  String get mixedMilk;

  /// Price per liter of milk
  ///
  /// In en, this message translates to:
  /// **'Rate per Liter'**
  String get ratePerLiter;

  /// Milk volume or quantity label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// Unit label for liters
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get liters;

  /// Unit label for milliliters
  ///
  /// In en, this message translates to:
  /// **'Milliliters'**
  String get milliliters;

  /// Delivery status action or badge indicating successful delivery
  ///
  /// In en, this message translates to:
  /// **'✔ Delivered'**
  String get delivered;

  /// Delivery status action indicating customer skipped milk today
  ///
  /// In en, this message translates to:
  /// **'✕ Skipped Today'**
  String get notDeliveredToday;

  /// Short status indicator for skipped delivery
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// Delivery status badge showing active vacation pause
  ///
  /// In en, this message translates to:
  /// **'⛔ Milk Paused (Vacation)'**
  String get pausedVacation;

  /// General term for delivery pause or vacation period
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get vacation;

  /// Button or header to record milk delivery
  ///
  /// In en, this message translates to:
  /// **'Delivery Entry'**
  String get deliveryEntry;

  /// Single delivery route label
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// Plural label for delivery routes management
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routes;

  /// Label for sequential stop ordering along delivery route
  ///
  /// In en, this message translates to:
  /// **'Stop Sequence'**
  String get stopSequence;

  /// Ordered sequence number of customer on route
  ///
  /// In en, this message translates to:
  /// **'Customer Sequence'**
  String get customerSequence;

  /// Header for list of customers assigned to route
  ///
  /// In en, this message translates to:
  /// **'Route Customers'**
  String get routeCustomers;

  /// Action to drag and drop reorder stops
  ///
  /// In en, this message translates to:
  /// **'Reorder Stops'**
  String get reorderStops;

  /// Action to create a new delivery route
  ///
  /// In en, this message translates to:
  /// **'Add Route'**
  String get addRoute;

  /// Action to modify route details
  ///
  /// In en, this message translates to:
  /// **'Edit Route'**
  String get editRoute;

  /// Action to delete a route
  ///
  /// In en, this message translates to:
  /// **'Delete Route'**
  String get deleteRoute;

  /// Input field label for naming a route
  ///
  /// In en, this message translates to:
  /// **'Route Name'**
  String get routeName;

  /// Button label initiating NPCI UPI payment intent
  ///
  /// In en, this message translates to:
  /// **'Pay via UPI'**
  String get payViaUpi;

  /// Header or instructions for static UPI QR code modal
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code to Pay'**
  String get scanQrToPay;

  /// Action or badge for doorstep cash collection
  ///
  /// In en, this message translates to:
  /// **'Cash Collected'**
  String get cashCollected;

  /// Full label for in-person cash payment logging
  ///
  /// In en, this message translates to:
  /// **'Doorstep Cash Collected'**
  String get doorstepCashCollected;

  /// Action launching native WhatsApp invoice message
  ///
  /// In en, this message translates to:
  /// **'Share Invoice on WhatsApp'**
  String get shareInvoiceWhatsapp;

  /// Header and label for monthly billing invoice
  ///
  /// In en, this message translates to:
  /// **'Monthly Bill'**
  String get monthlyBill;

  /// Summary label for aggregated milk liters in billing period
  ///
  /// In en, this message translates to:
  /// **'Total Liters'**
  String get totalLiters;

  /// Summary label for aggregated billed amount
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Label for remaining unpaid balance
  ///
  /// In en, this message translates to:
  /// **'Pending Amount'**
  String get pendingAmount;

  /// Label for recorded payments received
  ///
  /// In en, this message translates to:
  /// **'Paid Amount'**
  String get paidAmount;

  /// Header for month-to-date consumption and cost summary
  ///
  /// In en, this message translates to:
  /// **'Monthly Summary'**
  String get monthlySummary;

  /// Header and button to log payment collection
  ///
  /// In en, this message translates to:
  /// **'Record Collection'**
  String get recordCollection;

  /// Action button for customer to request vacation pause
  ///
  /// In en, this message translates to:
  /// **'Pause Milk Delivery'**
  String get pauseMilk;

  /// Header for customer vacation pause request dialog
  ///
  /// In en, this message translates to:
  /// **'Pause Request'**
  String get pauseRequest;

  /// Calendar field for pause starting date
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// Calendar field for pause ending date
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// Optional notes or reason for delivery pause
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// Section header for pause requests awaiting seller review
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get pendingApprovals;

  /// Action button to approve customer vacation pause
  ///
  /// In en, this message translates to:
  /// **'Approve Pause'**
  String get approvePause;

  /// Action button to reject customer vacation pause
  ///
  /// In en, this message translates to:
  /// **'Reject Pause'**
  String get rejectPause;

  /// Label for app language configuration
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Name of English language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Name of Hindi language
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// Bilingual label for Devanagari Hindi
  ///
  /// In en, this message translates to:
  /// **'Hindi (हिंदी)'**
  String get hindiLanguage;

  /// Label for English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// Settings action title for toggling app language
  ///
  /// In en, this message translates to:
  /// **'Switch Language'**
  String get switchLanguage;

  /// Bilingual subtitle explaining language switch
  ///
  /// In en, this message translates to:
  /// **'Switch app language / ऐप की भाषा बदलें'**
  String get switchLanguageSubtitle;

  /// Delivery sheet toggle to prevent screen timeout
  ///
  /// In en, this message translates to:
  /// **'Keep Screen Awake'**
  String get keepScreenAwake;

  /// Sign out action button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Subtitle describing logout effect
  ///
  /// In en, this message translates to:
  /// **'Ends session and clears Remember Me'**
  String get logoutSubtitle;

  /// Personalized dashboard greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome, {userName}'**
  String welcomeUser(String userName);

  /// Visual stop badge display on customer card
  ///
  /// In en, this message translates to:
  /// **'Stop #{sequence}'**
  String stopSequenceBadge(int sequence);

  /// Rupee currency formatting
  ///
  /// In en, this message translates to:
  /// **'₹{amount}'**
  String formatRupees(String amount);

  /// Milk volume formatting in liters
  ///
  /// In en, this message translates to:
  /// **'{liters} L'**
  String formatLiters(String liters);

  /// Filter option to view all delivery shifts
  ///
  /// In en, this message translates to:
  /// **'All Shifts'**
  String get allShifts;

  /// Header for route management screen
  ///
  /// In en, this message translates to:
  /// **'Manage Routes'**
  String get manageRoutes;

  /// Empty state message when no delivery routes exist
  ///
  /// In en, this message translates to:
  /// **'No delivery routes found'**
  String get noRoutesFound;

  /// Helper text guiding user to create a route
  ///
  /// In en, this message translates to:
  /// **'Create your first route to organize deliveries'**
  String get createFirstRoute;

  /// Input field label for route description
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get routeDescription;

  /// Label for seller assigned to route
  ///
  /// In en, this message translates to:
  /// **'Assigned Seller'**
  String get assignedSeller;

  /// Dropdown placeholder to pick a seller
  ///
  /// In en, this message translates to:
  /// **'Select Seller'**
  String get selectSeller;

  /// Indicates route is handled directly by dairy owner
  ///
  /// In en, this message translates to:
  /// **'No seller assigned (Owner Delivery)'**
  String get noSellerAssigned;

  /// Status badge for customer or route without assigned seller
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// Pluralized customer count badge
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No customers} =1{1 Customer} other{{count} Customers}}'**
  String customerCountBadge(int count);

  /// Title for route deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Route'**
  String get deleteRouteConfirmTitle;

  /// Warning message before deleting route
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this route? Customer sequence assignments will be reset.'**
  String get deleteRouteConfirmMessage;

  /// Snackbar message after reordering customer stops
  ///
  /// In en, this message translates to:
  /// **'Customer delivery sequence updated successfully'**
  String get sequenceUpdated;

  /// Snackbar confirmation after creating or editing a route
  ///
  /// In en, this message translates to:
  /// **'Route saved successfully'**
  String get routeSaved;

  /// Snackbar confirmation after deleting a route
  ///
  /// In en, this message translates to:
  /// **'Route deleted successfully'**
  String get routeDeleted;

  /// Action button to persist stop sequence ordering
  ///
  /// In en, this message translates to:
  /// **'Save Sequence'**
  String get saveSequence;

  /// Instruction subtitle for reorderable list
  ///
  /// In en, this message translates to:
  /// **'Drag handles to reorder delivery stops'**
  String get dragToReorder;

  /// Dropdown or filter title for choosing a route
  ///
  /// In en, this message translates to:
  /// **'Select Route'**
  String get selectRoute;

  /// Filter tab showing all delivery routes
  ///
  /// In en, this message translates to:
  /// **'All Routes'**
  String get allRoutes;

  /// Badge indicating currently selected route
  ///
  /// In en, this message translates to:
  /// **'Active Route'**
  String get activeRoute;

  /// Placeholder when seller has no assigned routes
  ///
  /// In en, this message translates to:
  /// **'No routes assigned yet'**
  String get noRoutesAssigned;

  /// Button to begin delivery along the selected route
  ///
  /// In en, this message translates to:
  /// **'Start Delivery'**
  String get startDelivery;

  /// Button to inspect route customer list
  ///
  /// In en, this message translates to:
  /// **'View Customers'**
  String get viewCustomers;

  /// Header for daily milk allocation and stock
  ///
  /// In en, this message translates to:
  /// **'Today\'s Inventory'**
  String get todaysInventory;

  /// Inventory metric: allocated milk volume
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// Inventory metric: delivered milk volume today
  ///
  /// In en, this message translates to:
  /// **'Sold Today'**
  String get soldToday;

  /// Inventory metric: remaining unsold milk volume
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// Header for cash and billing collection summary
  ///
  /// In en, this message translates to:
  /// **'Collection Snapshot'**
  String get collectionSnapshot;

  /// Metric: total amount billed for period
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get billed;

  /// Metric: total amount collected
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get collected;

  /// Calendar reminder action for delivery route schedule
  ///
  /// In en, this message translates to:
  /// **'Delivery Reminder'**
  String get deliveryReminder;

  /// Calendar reminder action for restocking milk inventory
  ///
  /// In en, this message translates to:
  /// **'Stock Refill'**
  String get stockRefill;

  /// Action to open monthly delivery calendar
  ///
  /// In en, this message translates to:
  /// **'Open Calendar'**
  String get openCalendar;

  /// Greeting header on dashboard
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Error banner when user lacks seller record
  ///
  /// In en, this message translates to:
  /// **'Seller record not found.\nPlease contact admin.'**
  String get sellerNotFound;

  /// Placeholder for empty route customer list
  ///
  /// In en, this message translates to:
  /// **'No customers on this route'**
  String get noCustomersOnRoute;

  /// Direct delivery route launcher for dairy owners
  ///
  /// In en, this message translates to:
  /// **'Owner-Seller Delivery'**
  String get ownerDelivery;

  /// Action button to execute delivery run on route
  ///
  /// In en, this message translates to:
  /// **'Deliver Route'**
  String get deliverRoute;

  /// One-touch button to start active delivery
  ///
  /// In en, this message translates to:
  /// **'Deliver Now'**
  String get quickDeliver;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
