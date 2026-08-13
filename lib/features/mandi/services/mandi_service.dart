import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mandi_data_model.dart';
import '../../../core/network/http_client_provider.dart';

// ─── Helpers for commodity matching & isolate offloading ────────────────────

/// Core commodity string matching algorithm.
/// Matches exact equality, or substring containment in either direction.
List<dynamic> _matchCommodityRecords(List<dynamic> records, String searchCrop) {
  if (records.isEmpty || searchCrop.isEmpty) return [];
  final cropTerm = searchCrop.trim().toLowerCase();
  final matched = <dynamic>[];
  for (final r in records) {
    if (r is! Map) continue;
    final cm = (r['commodity']?.toString() ?? '').trim().toLowerCase();
    if (cm.isEmpty) continue;
    if (cropTerm == cm || cropTerm.contains(cm) || cm.contains(cropTerm)) {
      matched.add(r);
    }
  }
  return matched;
}

/// Top-level helper function for compute() isolate execution.
List<dynamic> _matchCommodityIsolate(List<dynamic> args) {
  return _matchCommodityRecords(args[0] as List<dynamic>, args[1] as String);
}

class MandiService {
  MandiService._();
  static final MandiService instance = MandiService._();

  static const String _apiKey = '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';
  static const String _resourceId = '9ef84268-d588-465a-a308-a864a43d0070';
  static const String _baseUrl = 'https://api.data.gov.in/resource/$_resourceId';

  /// Threshold for isolate filtering.
  /// Datasets with <= 50 records are filtered synchronously on the main thread
  /// to avoid isolate spawn and deep-copy serialization overhead.
  /// Datasets with > 50 records use compute() to offload CPU work.
  static const int _isolateThreshold = 50;

  // In-Memory API Response Cache (5 minute TTL)
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTime = {};

  // Uses shared app-wide http.Client to avoid separate connection pools.
  http.Client get _client => AppHttpClient.instance;

  static const Map<String, List<String>> indianStatesDistricts = {
    "Andhra Pradesh": ["Anantapur", "Chittoor", "East Godavari", "Guntur", "Krishna", "Kurnool", "Prakasam", "Srikakulam", "Visakhapatnam", "Vizianagaram", "West Godavari", "YSR Kadapa", "Nandyal", "Eluru", "NTR"],
    "Arunachal Pradesh": ["Changlang", "East Kameng", "East Siang", "Lohit", "Papum Pare", "Tawang", "Tirap", "West Kameng"],
    "Assam": ["Baksa", "Barpeta", "Bongaigaon", "Cachar", "Darrang", "Dhubri", "Dibrugarh", "Goalpara", "Golaghat", "Jorhat", "Kamrup", "Kamrup Metropolitan", "Karbi Anglong", "Karimganj", "Lakhimpur", "Nagaon", "Nalbari", "Sivasagar", "Sonitpur", "Tinsukia"],
    "Bihar": ["Araria", "Aurangabad", "Banka", "Begusarai", "Bhagalpur", "Bhojpur", "Buxar", "Darbhanga", "Gaya", "Gopalganj", "Jamui", "Katihar", "Khagaria", "Madhepura", "Madhubani", "Munger", "Muzaffarpur", "Nalanda", "Nawada", "Patna", "Purnia", "Rohtas", "Samastipur", "Saran", "Sitamarhi", "Siwan", "Vaishali"],
    "Chhattisgarh": ["Balod", "Bastar", "Bepametara", "Bilaspur", "Dhamtari", "Durg", "Janagir-Champa", "Kanker", "Kawardha", "Korba", "Mahasamund", "Raigarh", "Raipur", "Rajnandgaon", "Surguja"],
    "Goa": ["North Goa", "South Goa"],
    "Gujarat": ["Ahmedabad", "Amreli", "Anand", "Banaskantha", "Bharuch", "Bhavnagar", "Botad", "Dahod", "Gandhinagar", "Jamnagar", "Junagadh", "Kheda", "Kutch", "Mehsana", "Morbi", "Narmada", "Navsari", "Patan", "Porbandar", "Rajkot", "Sabarkantha", "Surat", "Surendranagar", "Vadodara", "Valsad"],
    "Haryana": ["Ambala", "Bhiwani", "Charkhi Dadri", "Faridabad", "Fatehabad", "Gurugram", "Hissar", "Jhajjar", "Jind", "Kaithal", "Karnal", "Kurukshetra", "Mahendragarh", "Nuh", "Palwal", "Panchkula", "Panipat", "Rewari", "Rohtak", "Sirsa", "Sonipat", "Yamunanagar"],
    "Himachal Pradesh": ["Bilaspur", "Chamba", "Hamirpur", "Kangra", "Kinnaur", "Kullu", "Mandi", "Shimla", "Sirmaur", "Solan", "Una"],
    "Jammu and Kashmir": ["Anantnag", "Bandipora", "Baramulla", "Budgam", "Doda", "Ganderbal", "Jammu", "Kathua", "Kishtwar", "Kulgam", "Kupwara", "Poonch", "Pulwama", "Rajouri", "Ramban", "Reasi", "Samba", "Shopian", "Srinagar", "Udhampur"],
    "Jharkhand": ["Bokaro", "Chatra", "Deoghar", "Dhanbad", "Dumka", "East Singhbhum", "Garhwa", "Giridih", "Godda", "Gumla", "Hazaribagh", "Jamtara", "Khunti", "Koderma", "Latehar", "Lohardaga", "Pakur", "Palamu", "Ranchi", "Sahibganj", "West Singhbhum"],
    "Karnataka": ["Bagalkot", "Ballari", "Belagavi", "Bengaluru Rural", "Bengaluru Urban", "Bidar", "Chamarajanagar", "Chikkaballapur", "Chikkamagaluru", "Chitradurga", "Dakshina Kannada", "Davanagere", "Dharwad", "Gadag", "Hassan", "Haveri", "Kalaburagi", "Kodagu", "Kolar", "Koppal", "Mandya", "Mysuru", "Raichur", "Ramanagara", "Shivamogga", "Tumakuru", "Udupi", "Uttara Kannada", "Vijayanagara", "Yadgir"],
    "Kerala": ["Alappuzha", "Ernakulam", "Idukki", "Kannur", "Kasaragod", "Kollam", "Kottayam", "Kozhikode", "Malappuram", "Palakkad", "Pathanamthitta", "Thiruvananthapuram", "Thrissur", "Wayanad"],
    "Madhya Pradesh": ["Agar Malwa", "Alirajpur", "Anuppur", "Ashoknagar", "Balaghat", "Barwani", "Betul", "Bhind", "Bhopal", "Burhanpur", "Chhatarpur", "Chhindwara", "Damoh", "Datia", "Dewas", "Dhar", "Dindori", "Guna", "Gwalior", "Harda", "Hoshangabad", "Indore", "Jabalpur", "Jhabua", "Katni", "Khandwa", "Khargone", "Mandla", "Mandsaur", "Morena", "Narsinghpur", "Neemuch", "Panna", "Raisen", "Rajgarh", "Ratlam", "Rewa", "Sagar", "Satna", "Sehore", "Seoni", "Shahdol", "Shajapur", "Sheopur", "Shivpuri", "Sidhi", "Singrauli", "Tikamgarh", "Ujjain", "Umaria", "Vidisha"],
    "Maharashtra": ["Ahilyanagar", "Akola", "Amravati", "Beed", "Bhandara", "Buldhana", "Chandrapur", "Chattrapati Sambhajinagar", "Dhule", "Gadchiroli", "Gondia", "Hingoli", "Jalgaon", "Jalna", "Kolhapur", "Latur", "Mumbai City", "Mumbai Suburban", "Nagpur", "Nanded", "Nandurbar", "Nashik", "Dharashiv", "Palghar", "Parbhani", "Pune", "Raigad", "Ratnagiri", "Sangli", "Satara", "Sindhudurg", "Solapur", "Thane", "Wardha", "Washim", "Yavatmal"],
    "Manipur": ["Bishnupur", "Chandel", "Churachandpur", "Imphal East", "Imphal West", "Senapati", "Tamenglong", "Thoubal", "Ukhrul"],
    "Meghalaya": ["East Garo Hills", "East Jaintia Hills", "East Khasi Hills", "North Garo Hills", "Ri Bhoi", "South Garo Hills", "West Garo Hills", "West Jaintia Hills", "West Khasi Hills"],
    "Mizoram": ["Aizawl", "Champhai", "Kolasib", "Lunglei", "Mamit", "Saiha", "Serchhip"],
    "Nagaland": ["Dimapur", "Kohima", "Mokokchung", "Mon", "Phek", "Tuensang", "Wokha", "Zunheboto"],
    "Odisha": ["Angul", "Balangir", "Balasore", "Bargarh", "Bhadrak", "Boudh", "Cuttack", "Deogarh", "Dhenkanal", "Gajapati", "Ganjam", "Jagatsinghpur", "Jajpur", "Jharsuguda", "Kalahandi", "Kandhamal", "Kendrapara", "Kendujhar", "Khordha", "Koraput", "Malkangiri", "Mayurbhanj", "Nabarangpur", "Nayagarh", "Nuapada", "Puri", "Rayagada", "Sambalpur", "Subarnapur", "Sundergarh"],
    "Punjab": ["Amritsar", "Barnala", "Bathinda", "Faridkot", "Fatehgarh Sahib", "Fazilka", "Ferozepur", "Gurdaspur", "Hoshiarpur", "Jalandhar", "Kapurthala", "Ludhiana", "Mansa", "Moga", "Muktsar", "Pathankot", "Patiala", "Rupnagar", "Sangrur", "SAS Nagar (Mohali)", "SBS Nagar", "Tarntaran"],
    "Rajasthan": ["Ajmer", "Alwar", "Banswara", "Baran", "Barmer", "Bharatpur", "Bhilwara", "Bikaner", "Bundi", "Chittorgarh", "Churu", "Dausa", "Dholpur", "Dungarpur", "Hanumangarh", "Jaipur", "Jaisalmer", "Jalore", "Jhalawar", "Jhunjhunu", "Jodhpur", "Karauli", "Kota", "Nagaur", "Pali", "Pratapgarh", "Rajsamand", "Sawai Madhopur", "Sikar", "Sirohi", "Sri Ganganagar", "Tonk", "Udaipur"],
    "Sikkim": ["East Sikkim", "North Sikkim", "South Sikkim", "West Sikkim"],
    "Tamil Nadu": ["Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri", "Dindigul", "Erode", "Kanchipuram", "Kanyakumari", "Karur", "Krishnagiri", "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur", "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi", "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur", "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram", "Virudhunagar"],
    "Telangana": ["Adilabad", "Bhadradri Kothagudem", "Hyderabad", "Jagtial", "Jangaon", "Jayashankar Bhupalpally", "Jogulamba Gadwal", "Kamareddy", "Karimnagar", "Khammam", "Kumuram Bheem", "Mahabubabad", "Mahabubnagar", "Mancherial", "Medak", "Medchal-Malkajgiri", "Mulugu", "Nalgonda", "Narayanpet", "Nirmal", "Nizamabad", "Peddapalli", "Rajanna Sircilla", "Rangareddy", "Sangareddy", "Siddipet", "Suryapet", "Vikarabad", "Wanaparthy", "Warangal", "Yadadri Bhuvanagiri"],
    "Tripura": ["Dhalai", "Gomati", "Khowai", "North Tripura", "Sepahijala", "South Tripura", "Unakoti", "West Tripura"],
    "Uttar Pradesh": ["Agra", "Aligarh", "Ambedkar Nagar", "Amethi", "Amroha", "Auraiya", "Ayodhya", "Azamgarh", "Badaun", "Baghpat", "Bahraich", "Ballia", "Balrampur", "Banda", "Barabanki", "Bareilly", "Basti", "Bhajnoi", "Bijnor", "Bulandshahr", "Chandauli", "Chitrakoot", "Deoria", "Etah", "Etawah", "Farrukhabad", "Fatehpur", "Firozabad", "Gautam Buddha Nagar", "Ghaziabad", "Ghazipur", "Gonda", "Gorakhpur", "Hamirpur", "Hapur", "Hardoi", "Hathras", "Jalaun", "Jaunpur", "Jhansi", "Kannauj", "Kanpur Dehat", "Kanpur Nagar", "Kasganj", "Kaushambi", "Kheri", "Kushinagar", "Lalitpur", "Lucknow", "Maharajganj", "Mahoba", "Mainpuri", "Mathura", "Mau", "Meerut", "Mirzapur", "Moradabad", "Muzaffarnagar", "Pilibhit", "Pratapgarh", "Prayagraj", "Raebareli", "Rampur", "Saharanpur", "Sambhal", "Sant Kabir Nagar", "Shahjahanpur", "Shamli", "Shravasti", "Siddharthnagar", "Sitapur", "Sonbhadra", "Sultanpur", "Unnao", "Varanasi"],
    "Uttarakhand": ["Almora", "Bageshwar", "Chamoli", "Champawat", "Dehradun", "Haridwar", "Nainital", "Pauri Garhwal", "Pithoragarh", "Rudraprayag", "Tehri Garhwal", "Udham Singh Nagar", "Uttarkashi"],
    "West Bengal": ["Alipurduar", "Bankura", "Birbhum", "Cooch Behar", "Dakshin Dinajpur", "Darjeeling", "Hooghly", "Howrah", "Jalpaiguri", "Jhargram", "Kalimpong", "Kolkata", "Malda", "Murshidabad", "Nadia", "North 24 Parganas", "Paschim Bardhaman", "Paschim Medinipur", "Purba Bardhaman", "Purba Medinipur", "Purulia", "South 24 Parganas", "Uttar Dinajpur"]
  };

  static const List<String> popularCommodities = [
    "Apple", "Arhar (Tur/Red Gram)", "Ashgourd", "Bajra(Pearl Millet/Cumbu)", "Banana", "Banana - Green", 
    "Barley (Jau)", "Bengal Gram(Gram)(Whole)", "Bitter gourd", "Bhindi(Ladies Finger)", "Black Gram (Urd Beans)", 
    "Bottle gourd", "Brinjal", "Cabbage", "Capsicum", "Carrot", "Cauliflower", "Chili Red", "Chilli Green", 
    "Coconut", "Coriander(Leaves)", "Cotton", "Cucumber", "Cumin Seed(Jeera)", "Drumstick", "Fish", "Garlic", 
    "Ginger(Green)", "Grapes", "Green Gram (Moong)", "Groundnut", "Guava", "Jowar(Sorghum)", "Lemon", 
    "Maize", "Mango", "Mustard", "Onion", "Papaya", "Papaya(Raw)", "Peas(Dry)", "Peas wet", "Pomegranate", 
    "Potato", "Pumpkin", "Radish", "Ragi (Finger Millet)", "Rice", "Soyabean", "Spinach", "Sugarcane", 
    "Sweet Potato", "Tomato", "Turmeric", "Watermelon", "Wheat"
  ];

  Future<List<dynamic>> _fetchRecords(Map<String, String> queryParams) async {
    final key = Uri(queryParameters: queryParams).query;
    final now = DateTime.now();

    if (_cache.containsKey(key) && _cacheTime.containsKey(key)) {
      if (now.difference(_cacheTime[key]!).inSeconds < 300) {
        return _cache[key] as List<dynamic>;
      }
    }

    try {
      final uri = Uri.parse('$_baseUrl?api-key=$_apiKey&format=json&$key');
      final res = await _client.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 MandiPriceApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final records = data['records'] as List<dynamic>? ?? [];
        _cache[key] = records;
        _cacheTime[key] = now;
        return records;
      }
    } catch (_) {
      if (_cache.containsKey(key)) {
        return _cache[key] as List<dynamic>;
      }
    }
    return [];
  }

  /// Filters [records] for matching [commodity].
  /// Uses synchronous filtering for <= [_isolateThreshold] records to avoid
  /// isolate spawn & serialization overhead. Uses compute() for larger datasets.
  Future<List<dynamic>> _filterCommodity(List<dynamic> records, String commodity) async {
    if (records.length <= _isolateThreshold) {
      return _matchCommodityRecords(records, commodity);
    }
    return compute(_matchCommodityIsolate, [records, commodity]);
  }

  double _safeDouble(dynamic val, [double defaultValue = 0.0]) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    final parsed = double.tryParse(val.toString());
    return parsed ?? defaultValue;
  }

  Future<MandiResponse> fetchPrices({
    required String state,
    required String district,
    required String commodity,
  }) async {
    List<dynamic>? allIndiaMatched;

    // 1. District Level Records
    var districtRaw = await _fetchRecords({
      'limit': '500',
      'filters[state]': state,
      'filters[district]': district,
    });
    var matchedRecords = await _filterCommodity(districtRaw, commodity);
    String scopeNote = 'Mandis in $district, $state';

    // 2. Fallback to State level
    if (matchedRecords.isEmpty) {
      var stateRaw = await _fetchRecords({
        'limit': '500',
        'filters[state]': state,
      });
      matchedRecords = await _filterCommodity(stateRaw, commodity);
      if (matchedRecords.isNotEmpty) {
        scopeNote = '$state Mandis (Nearest to $district)';
      }
    }

    // 3. Fallback to All-India records
    if (matchedRecords.isEmpty) {
      var allIndiaRaw = await _fetchRecords({
        'limit': '500',
        'filters[commodity]': commodity,
      });
      allIndiaMatched = await _filterCommodity(allIndiaRaw, commodity);
      matchedRecords = allIndiaMatched;
      if (matchedRecords.isNotEmpty) {
        scopeNote = 'Mandis Reporting Prices for $commodity (Nearest to $district, $state)';
      }
    }

    // 4. Fallback to active Mandis in District/State
    if (matchedRecords.isEmpty) {
      if (districtRaw.isNotEmpty) {
        matchedRecords = districtRaw;
        scopeNote = 'All Active Mandis in $district, $state';
      } else {
        var bulkRecs = await _fetchRecords({'limit': '200'});
        matchedRecords = bulkRecs.take(10).toList();
        scopeNote = 'Active Indian Mandis';
      }
    }

    // Process all local mandi price records
    final localMandis = <MandiPriceRecord>[];
    final seenKeys = <String>{};

    for (final r in matchedRecords) {
      if (r is! Map) continue;
      final jsonMap = Map<String, dynamic>.from(r);

      final mName = jsonMap['market']?.toString() ?? 'Local Mandi';
      final variety = jsonMap['variety']?.toString() ?? 'Standard';
      final key = '$mName-$variety';

      if (seenKeys.contains(key)) continue;

      final modalP = _safeDouble(jsonMap['modal_price_quintal'] ?? jsonMap['modal_price']);
      final maxP = _safeDouble(jsonMap['max_price_quintal'] ?? jsonMap['max_price'], modalP);
      final minP = _safeDouble(jsonMap['min_price_quintal'] ?? jsonMap['min_price'], modalP);

      var effectiveModal = modalP;
      if (effectiveModal <= 0 && maxP > 0) effectiveModal = maxP;
      if (effectiveModal <= 0 && minP > 0) effectiveModal = minP;

      if (effectiveModal > 0) {
        seenKeys.add(key);
        localMandis.add(MandiPriceRecord.fromJson(jsonMap, district, state, commodity));
      }
    }

    // Reuse All-India Records for Highest Market Price if already fetched in fallback,
    // otherwise fetch & filter them now.
    if (allIndiaMatched == null) {
      var allIndiaRaw = await _fetchRecords({
        'limit': '500',
        'filters[commodity]': commodity,
      });
      allIndiaMatched = await _filterCommodity(allIndiaRaw, commodity);
    }

    if (allIndiaMatched.isEmpty && matchedRecords.isNotEmpty) {
      allIndiaMatched = matchedRecords;
    }

    MandiHighestRecord? highestRecord;
    if (allIndiaMatched.isNotEmpty) {
      double maxPriceFound = -1;
      Map<String, dynamic>? topRec;

      for (final r in allIndiaMatched) {
        if (r is! Map) continue;
        final jsonMap = Map<String, dynamic>.from(r);
        final maxP = _safeDouble(jsonMap['max_price_quintal'] ?? jsonMap['max_price'] ?? jsonMap['modal_price']);
        if (maxP > maxPriceFound) {
          maxPriceFound = maxP;
          topRec = jsonMap;
        }
      }

      if (topRec != null) {
        highestRecord = MandiHighestRecord.fromJson(topRec);
      }
    }

    double? diffAmountQuintal;
    double? diffPercent;

    if (localMandis.isNotEmpty && highestRecord != null) {
      final localPrice = localMandis.first.modalPriceQuintal;
      if (localPrice > 0 && highestRecord.maxPriceQuintal > localPrice) {
        final diff = highestRecord.maxPriceQuintal - localPrice;
        diffAmountQuintal = _safeDouble(diff.toStringAsFixed(2));
        diffPercent = _safeDouble(((diffAmountQuintal / localPrice) * 100).toStringAsFixed(1));
      }
    }

    return MandiResponse(
      queryState: state,
      queryDistrict: district,
      queryCommodity: commodity,
      localMandis: localMandis,
      scopeNote: scopeNote,
      highest: highestRecord,
      diffAmountQuintal: diffAmountQuintal,
      diffPercent: diffPercent,
    );
  }
}
