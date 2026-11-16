// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Milk HUB';

  @override
  String get admin => 'व्यवस्थापक (Admin)';

  @override
  String get seller => 'विक्रेता';

  @override
  String get customer => 'ग्राहक';

  @override
  String get customers => 'ग्राहक';

  @override
  String get doodhwala => 'दूधवाला';

  @override
  String get deliveryBoy => 'वितरण सहायक';

  @override
  String get soloMilkman => 'स्वतंत्र दूध विक्रेता';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get edit => 'संपादित करें';

  @override
  String get add => 'जोड़ें';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get search => 'खोजें';

  @override
  String get refresh => 'रिफ्रेश करें';

  @override
  String get back => 'वापस';

  @override
  String get submit => 'जमा करें';

  @override
  String get done => 'पूर्ण';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get pending => 'लंबित';

  @override
  String get approved => 'स्वीकृत';

  @override
  String get rejected => 'अस्वीकृत';

  @override
  String get active => 'सक्रिय';

  @override
  String get inactive => 'निष्क्रिय';

  @override
  String get shift => 'शिफ्ट';

  @override
  String get morningShift => 'सुबह';

  @override
  String get eveningShift => 'शाम';

  @override
  String get bothShifts => 'दोनों समय';

  @override
  String get cowMilk => 'गाय का दूध';

  @override
  String get buffaloMilk => 'भैंस का दूध';

  @override
  String get mixedMilk => 'मिश्रित दूध';

  @override
  String get ratePerLiter => 'प्रति लीटर दर';

  @override
  String get quantity => 'मात्रा';

  @override
  String get liters => 'लीटर';

  @override
  String get milliliters => 'मिलीलीटर';

  @override
  String get delivered => '✔ दिया';

  @override
  String get notDeliveredToday => '✕ आज नहीं लिया';

  @override
  String get skipped => 'नहीं लिया';

  @override
  String get pausedVacation => '⛔ आज दूध बंद (छुट्टी)';

  @override
  String get vacation => 'छुट्टी (अवकाश)';

  @override
  String get deliveryEntry => 'दूध वितरण दर्ज करें';

  @override
  String get route => 'मार्ग';

  @override
  String get routes => 'वितरण मार्ग';

  @override
  String get stopSequence => 'स्टॉप क्रम';

  @override
  String get customerSequence => 'ग्राहक क्रम';

  @override
  String get routeCustomers => 'मार्ग के ग्राहक';

  @override
  String get reorderStops => 'स्टॉप क्रम बदलें';

  @override
  String get addRoute => 'नया मार्ग जोड़ें';

  @override
  String get editRoute => 'मार्ग संपादित करें';

  @override
  String get deleteRoute => 'मार्ग हटाएं';

  @override
  String get routeName => 'मार्ग का नाम';

  @override
  String get payViaUpi => 'UPI द्वारा भुगतान करें';

  @override
  String get scanQrToPay => 'QR कोड स्कैन करें';

  @override
  String get cashCollected => 'नकद मिला';

  @override
  String get doorstepCashCollected => 'नकद मिला';

  @override
  String get shareInvoiceWhatsapp => 'WhatsApp पर बिल भेजें';

  @override
  String get monthlyBill => 'मासिक बिल';

  @override
  String get totalLiters => 'कुल लीटर';

  @override
  String get totalAmount => 'कुल राशि';

  @override
  String get pendingAmount => 'बाकी राशि';

  @override
  String get paidAmount => 'जमा राशि';

  @override
  String get monthlySummary => 'मासिक सारांश';

  @override
  String get recordCollection => 'वसूली दर्ज करें';

  @override
  String get pauseMilk => 'दूध बंद करें';

  @override
  String get pauseRequest => 'दूध बंद अनुरोध';

  @override
  String get startDate => 'प्रारंभ तिथि';

  @override
  String get endDate => 'समाप्ति तिथि';

  @override
  String get reason => 'कारण';

  @override
  String get pendingApprovals => 'लंबित स्वीकृतियां';

  @override
  String get approvePause => 'स्वीकार करें';

  @override
  String get rejectPause => 'अस्वीकार करें';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get hindiLanguage => 'हिंदी';

  @override
  String get englishLanguage => 'English';

  @override
  String get switchLanguage => 'भाषा बदलें';

  @override
  String get switchLanguageSubtitle => 'Switch app language / ऐप की भाषा बदलें';

  @override
  String get keepScreenAwake => 'स्क्रीन ऑन रखें';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get logoutSubtitle => 'सत्र समाप्त करें और पासवर्ड याद रखना हटाएं';

  @override
  String welcomeUser(String userName) {
    return 'स्वागत है, $userName';
  }

  @override
  String stopSequenceBadge(int sequence) {
    return 'स्टॉप #$sequence';
  }

  @override
  String formatRupees(String amount) {
    return '₹$amount';
  }

  @override
  String formatLiters(String liters) {
    return '$liters लीटर';
  }

  @override
  String get allShifts => 'सभी शिफ्ट';

  @override
  String get manageRoutes => 'मार्ग प्रबंधन';

  @override
  String get noRoutesFound => 'कोई वितरण मार्ग नहीं मिला';

  @override
  String get createFirstRoute => 'वितरण व्यवस्थित करने के लिए पहला मार्ग बनाएं';

  @override
  String get routeDescription => 'विवरण (वैकल्पिक)';

  @override
  String get assignedSeller => 'सौंपा गया विक्रेता';

  @override
  String get selectSeller => 'विक्रेता चुनें';

  @override
  String get noSellerAssigned => 'कोई विक्रेता नहीं (मालिक स्वयं वितरण)';

  @override
  String get unassigned => 'असाइन नहीं किया';

  @override
  String customerCountBadge(int count) {
    return '$count ग्राहक';
  }

  @override
  String get deleteRouteConfirmTitle => 'मार्ग हटाएं';

  @override
  String get deleteRouteConfirmMessage =>
      'क्या आप वाकई इस मार्ग को हटाना चाहते हैं? ग्राहकों के स्टॉप क्रम रीसेट हो जाएंगे।';

  @override
  String get sequenceUpdated => 'ग्राहक वितरण क्रम सफलतापूर्वक अपडेट किया गया';

  @override
  String get routeSaved => 'मार्ग सफलतापूर्वक सहेजा गया';

  @override
  String get routeDeleted => 'मार्ग सफलतापूर्वक हटा दिया गया';

  @override
  String get saveSequence => 'क्रम सहेजें';

  @override
  String get dragToReorder => 'वितरण क्रम बदलने के लिए खींचें';

  @override
  String get selectRoute => 'मार्ग चुनें';

  @override
  String get allRoutes => 'सभी मार्ग';

  @override
  String get activeRoute => 'सक्रिय मार्ग';

  @override
  String get noRoutesAssigned => 'अभी तक कोई मार्ग नहीं सौंपा गया';

  @override
  String get startDelivery => 'वितरण शुरू करें';

  @override
  String get viewCustomers => 'ग्राहक देखें';

  @override
  String get todaysInventory => 'आज का स्टॉक';

  @override
  String get assigned => 'आवंटित';

  @override
  String get soldToday => 'आज की बिक्री';

  @override
  String get remaining => 'बचा हुआ';

  @override
  String get collectionSnapshot => 'वसूली सारांश';

  @override
  String get billed => 'बिल बना';

  @override
  String get collected => 'वसूला गया';

  @override
  String get deliveryReminder => 'वितरण स्मरण';

  @override
  String get stockRefill => 'स्टॉक रिफिल';

  @override
  String get openCalendar => 'कैलेंडर खोलें';

  @override
  String get welcomeBack => 'वापसी पर स्वागत है';

  @override
  String get sellerNotFound =>
      'विक्रेता रिकॉर्ड नहीं मिला।\nकृपया व्यवस्थापक से संपर्क करें।';

  @override
  String get noCustomersOnRoute => 'इस मार्ग पर कोई ग्राहक नहीं हैं';

  @override
  String get ownerDelivery => 'मालिक स्वयं वितरण';

  @override
  String get deliverRoute => 'मार्ग पर दूध बांटें';

  @override
  String get quickDeliver => 'तुरंत वितरण करें';
}
