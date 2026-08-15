import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mandi_data_model.dart';
import '../../../core/network/http_client_provider.dart';

// ─── Helpers for commodity matching & isolate offloading ────────────────────

/// Vernacular Crop Aliases matching mandi.py
const Map<String, List<String>> cropAliases = {
  "rice": ["rice", "paddy", "paddy(dhan)(common)", "paddy(dhan)(basmati)", "dhan", "chawal"],
  "paddy": ["paddy", "rice", "paddy(dhan)(common)", "paddy(dhan)(basmati)", "dhan", "chawal"],
  "dhan": ["paddy", "rice", "paddy(dhan)(common)", "paddy(dhan)(basmati)"],
  "wheat": ["wheat", "gehun", "gehu"],
  "tur": ["arhar (tur/red gram)", "tur", "arhar", "red gram"],
  "arhar": ["arhar (tur/red gram)", "tur", "arhar", "red gram"],
  "red gram": ["arhar (tur/red gram)", "tur", "arhar"],
  "moong": ["green gram (moong)", "moong", "mung"],
  "green gram": ["green gram (moong)", "moong"],
  "urad": ["black gram (urd beans)", "urad", "urd"],
  "black gram": ["black gram (urd beans)", "urad", "urd"],
  "chana": ["bengal gram(gram)(whole)", "chana", "gram"],
  "gram": ["bengal gram(gram)(whole)", "chana", "gram"],
  "maize": ["maize", "corn", "makka"],
  "corn": ["maize", "corn", "makka"],
  "mustard": ["mustard", "sarson", "rai"],
  "sarson": ["mustard", "sarson"],
  "potato": ["potato", "aloo", "alu"],
  "aloo": ["potato", "aloo"],
  "onion": ["onion", "pyaaz", "pyaz"],
  "pyaaz": ["onion", "pyaaz"],
  "cotton": ["cotton", "kapas"],
  "groundnut": ["groundnut", "moongfali"],
  "soyabean": ["soyabean", "soya"],
  "jowar": ["jowar(sorghum)", "jowar", "sorghum"],
  "bajra": ["bajra(pearl millet/cumbu)", "bajra", "pearl millet"],
  "ragi": ["ragi (finger millet)", "ragi", "finger millet"],
  "arecanut": ["arecanut(betelnut/supari)", "arecanut", "supari", "betelnut"],
  "supari": ["arecanut(betelnut/supari)", "arecanut", "supari"],
  "chilli": ["chilli green", "chili red", "dry chillies", "green chilli", "chilli"],
  "chili": ["chilli green", "chili red", "dry chillies", "green chilli", "chilli"]
};

/// Expand input crop into synonymous government mandi commodity names.
List<String> getSearchTerms(String searchCrop) {
  final cropTerm = searchCrop.trim().toLowerCase();
  final terms = <String>{cropTerm};
  cropAliases.forEach((key, aliases) {
    if (key == cropTerm || key.contains(cropTerm) || cropTerm.contains(key)) {
      terms.addAll(aliases);
    }
  });
  return terms.toList();
}

/// Case-insensitive fuzzy and synonym matching for crop names.
List<dynamic> _matchCommodityRecords(List<dynamic> records, String searchCrop) {
  if (records.isEmpty || searchCrop.isEmpty) return [];
  final terms = getSearchTerms(searchCrop);
  final matched = <dynamic>[];
  for (final r in records) {
    if (r is! Map) continue;
    final cm = (r['commodity']?.toString() ?? '').trim().toLowerCase();
    if (cm.isEmpty) continue;
    for (final term in terms) {
      if (term == cm || term.contains(cm) || cm.contains(term)) {
        matched.add(r);
        break;
      }
    }
  }
  return matched;
}

List<dynamic> _matchCommodityIsolate(List<dynamic> args) {
  return _matchCommodityRecords(args[0] as List<dynamic>, args[1] as String);
}

// ─── Geographic Coordinates & Haversine Distance Calculation ──────────────────

/// State Capital / Center Coordinates (lat, lon)
const Map<String, List<double>> stateCenterCoordinates = {
  "Andhra Pradesh": [15.9129, 79.7400],
  "Arunachal Pradesh": [28.2180, 94.7278],
  "Assam": [26.2006, 92.9376],
  "Bihar": [25.0961, 85.3131],
  "Chhattisgarh": [21.2787, 81.8661],
  "Chattisgarh": [21.2787, 81.8661],
  "Goa": [15.2993, 74.1240],
  "Gujarat": [22.2587, 71.1924],
  "Haryana": [29.0588, 76.0856],
  "Himachal Pradesh": [31.1048, 77.1734],
  "Jammu and Kashmir": [33.7782, 76.5762],
  "Jharkhand": [23.6102, 85.2799],
  "Karnataka": [15.3173, 75.7139],
  "Kerala": [10.8505, 76.2711],
  "Madhya Pradesh": [22.9734, 78.6569],
  "Maharashtra": [19.7515, 75.7139],
  "Manipur": [24.6637, 93.9063],
  "Meghalaya": [25.4670, 91.3662],
  "Mizoram": [23.1645, 92.9376],
  "Nagaland": [26.1584, 94.5624],
  "Odisha": [20.9517, 85.0985],
  "Punjab": [31.1471, 75.3412],
  "Rajasthan": [27.0238, 74.2179],
  "Sikkim": [27.5330, 88.5122],
  "Tamil Nadu": [11.1271, 78.6569],
  "Telangana": [18.1124, 79.0193],
  "Tripura": [23.9408, 91.9882],
  "Uttar Pradesh": [26.8467, 80.9462],
  "Uttarakhand": [30.0668, 79.0193],
  "West Bengal": [22.9868, 87.8550]
};

/// Major District Coordinates (lat, lon) matching mandi.py
const Map<String, List<double>> districtCoordinates = {
  // Karnataka
  "Karnataka:Davanagere": [14.4674, 75.9241],
  "Karnataka:Davangere": [14.4674, 75.9241],
  "Karnataka:Bengaluru Urban": [12.9716, 77.5946],
  "Karnataka:Bengaluru Rural": [13.2257, 77.5750],
  "Karnataka:Bengaluru South": [12.9141, 77.5855],
  "Karnataka:Shivamogga": [13.9299, 75.5681],
  "Karnataka:Chamarajanagar": [11.9261, 76.9437],
  "Karnataka:Belagavi": [15.8497, 74.4977],
  "Karnataka:Ballari": [15.1394, 76.9214],
  "Karnataka:Kalaburagi": [17.3297, 76.8343],
  "Karnataka:Ramanagara": [12.7214, 77.2814],
  "Karnataka:Chitradurga": [14.2251, 76.3980],
  "Karnataka:Hassan": [13.0072, 76.1011],
  "Karnataka:Mandya": [12.5218, 76.8951],
  "Karnataka:Mysuru": [12.2958, 76.6394],
  "Karnataka:Tumakuru": [13.3379, 77.1173],
  "Karnataka:Dharwad": [15.4589, 75.0078],
  "Karnataka:Bagalkot": [16.1852, 75.6961],
  "Karnataka:Bidar": [17.9104, 77.5199],
  "Karnataka:Chikkamagaluru": [13.3153, 75.7754],
  "Karnataka:Dakshina Kannada": [12.8702, 74.8806],
  "Karnataka:Gadag": [15.4317, 75.6355],
  "Karnataka:Haveri": [14.7954, 75.3992],
  "Karnataka:Kolar": [13.1367, 78.1291],
  "Karnataka:Koppal": [15.3519, 76.1553],
  "Karnataka:Raichur": [16.2076, 77.3463],
  "Karnataka:Udupi": [13.3409, 74.7421],
  "Karnataka:Uttara Kannada": [14.8185, 74.1416],
  "Karnataka:Yadgir": [16.7700, 77.1378],

  // Maharashtra
  "Maharashtra:Kolhapur": [16.7050, 74.2433],
  "Maharashtra:Sangli": [16.8524, 74.5815],
  "Maharashtra:Solapur": [17.6599, 75.9064],
  "Maharashtra:Satara": [17.6805, 74.0183],
  "Maharashtra:Pune": [18.5204, 73.8567],
  "Maharashtra:Nashik": [19.9975, 73.7898],
  "Maharashtra:Chattrapati Sambhajinagar": [19.8762, 75.3433],
  "Maharashtra:Aurangabad": [19.8762, 75.3433],
  "Maharashtra:Jalna": [19.8410, 75.8864],
  "Maharashtra:Akola": [20.7002, 77.0082],
  "Maharashtra:Ahilyanagar": [19.0948, 74.7480],
  "Maharashtra:Ahmednagar": [19.0948, 74.7480],
  "Maharashtra:Latur": [18.4088, 76.5604],
  "Maharashtra:Nanded": [19.1383, 77.3210],

  // Madhya Pradesh
  "Madhya Pradesh:Badwani": [22.0354, 74.9048],
  "Madhya Pradesh:Barwani": [22.0354, 74.9048],
  "Madhya Pradesh:Indore": [22.7196, 75.8577],
  "Madhya Pradesh:Harda": [22.3394, 77.0967],
  "Madhya Pradesh:Sehore": [23.2031, 77.0845],
  "Madhya Pradesh:Sagar": [23.8388, 78.7378],
  "Madhya Pradesh:Shajapur": [23.4277, 76.2773],

  // Telangana
  "Telangana:Hyderabad": [17.3850, 78.4867],
  "Telangana:Nizamabad": [18.6725, 78.0941],
  "Telangana:Mahabubnagar": [16.7488, 77.9942],

  // Andhra Pradesh
  "Andhra Pradesh:NTR": [16.5062, 80.6480],
  "Andhra Pradesh:Guntur": [16.3067, 80.4365],
  "Andhra Pradesh:Chittoor": [13.2172, 79.1003],
  "Andhra Pradesh:Anantapur": [14.6819, 77.6006],

  // Kerala
  "Kerala:Ernakulam": [9.9816, 76.2999],
  "Kerala:Palakkad": [10.7867, 76.6548],
  "Kerala:Thrissur": [10.5276, 76.2144],

  // Gujarat
  "Gujarat:Dahod": [22.8347, 74.2543],
  "Gujarat:Surat": [21.1702, 72.8311],
  "Gujarat:Rajkot": [22.3039, 70.8022],
  "Gujarat:Ahmedabad": [23.0225, 72.5714],

  // Uttar Pradesh
  "Uttar Pradesh:Agra": [27.1767, 78.0081],
  "Uttar Pradesh:Azamgarh": [26.0682, 83.1843],
  "Uttar Pradesh:Lalitpur": [24.6896, 78.4120],
  "Uttar Pradesh:Lucknow": [26.8467, 80.9462],
  "Uttar Pradesh:Kanpur Nagar": [26.4499, 80.3319]
};

/// Calculate distance in km between two lat/lon coordinates using Haversine formula
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0; // Earth radius in km
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Retrieve coordinates for state/district with fallback to state center
List<double> getLocationCoords(String state, String district) {
  final key = "$state:$district";
  if (districtCoordinates.containsKey(key)) {
    return districtCoordinates[key]!;
  }
  for (final entry in districtCoordinates.entries) {
    final parts = entry.key.split(":");
    if (parts.length == 2) {
      final s = parts[0];
      final d = parts[1];
      if (s.toLowerCase() == state.toLowerCase() &&
          (d.toLowerCase().contains(district.toLowerCase()) ||
              district.toLowerCase().contains(d.toLowerCase()))) {
        return entry.value;
      }
    }
  }
  return stateCenterCoordinates[state] ?? [20.5937, 78.9629];
}

// ─── Mandi Service Implementation ─────────────────────────────────────────────

class MandiService {
  MandiService._();
  static final MandiService instance = MandiService._();

  static const String _apiKey = '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';
  static const String _resourceId = '9ef84268-d588-465a-a308-a864a43d0070';
  static const String _baseUrl = 'https://api.data.gov.in/resource/$_resourceId';

  static const int _isolateThreshold = 50;

  // In-Memory API Cache (5 minute TTL) to prevent 429 rate limits
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTime = {};

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
    "Apple", "Arecanut(Betelnut/Supari)", "Arhar (Tur/Red Gram)", "Ashgourd", "Bajra(Pearl Millet/Cumbu)", "Banana", "Banana - Green", 
    "Barley (Jau)", "Bengal Gram(Gram)(Whole)", "Bitter gourd", "Bhindi(Ladies Finger)", "Black Gram (Urd Beans)", 
    "Bottle gourd", "Brinjal", "Cabbage", "Capsicum", "Carrot", "Cauliflower", "Chili Red", "Chilli Green", 
    "Coconut", "Coriander(Leaves)", "Cotton", "Cucumber", "Cumin Seed(Jeera)", "Drumstick", "Fish", "Garlic", 
    "Ginger(Green)", "Grapes", "Green Gram (Moong)", "Groundnut", "Guava", "Jowar(Sorghum)", "Lemon", 
    "Maize", "Mango", "Mustard", "Onion", "Paddy(Dhan)(Common)", "Paddy(Dhan)(Basmati)", "Papaya", "Papaya(Raw)", "Peas(Dry)", "Peas wet", "Pomegranate", 
    "Potato", "Pumpkin", "Radish", "Ragi (Finger Millet)", "Rice", "Soyabean", "Spinach", "Sugarcane", 
    "Sweet Potato", "Tomato", "Turmeric", "Watermelon", "Wheat"
  ];

  Future<List<dynamic>> _fetchRecords(Map<String, String> queryParams, {int maxRecords = 100}) async {
    final key = Uri(queryParameters: queryParams).query;
    final cacheKey = "${key}_max$maxRecords";
    final now = DateTime.now();

    if (_cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
      if (now.difference(_cacheTime[cacheKey]!).inSeconds < 300) {
        return _cache[cacheKey] as List<dynamic>;
      }
    }

    final records = <dynamic>[];
    int offset = 0;
    const pageSize = 10;
    int total = 0;

    while (offset < maxRecords) {
      final currentParams = Map<String, String>.from(queryParams);
      currentParams['offset'] = offset.toString();
      currentParams['limit'] = pageSize.toString();

      final qStr = Uri(queryParameters: currentParams).query;
      final uri = Uri.parse('$_baseUrl?api-key=$_apiKey&format=json&$qStr');

      List<dynamic>? pageRecs;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await _client.get(
            uri,
            headers: {'User-Agent': 'Mozilla/5.0 MandiPriceApp/1.0'},
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            pageRecs = data['records'] as List<dynamic>? ?? [];
            total = (data['total'] as num?)?.toInt() ?? 0;
            break;
          } else if (res.statusCode == 429) {
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }

      if (pageRecs == null || pageRecs.isEmpty) break;
      records.addAll(pageRecs);
      offset += pageRecs.length;
      if (offset >= total) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (records.isNotEmpty) {
      _cache[cacheKey] = records;
      _cacheTime[cacheKey] = now;
    } else if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<dynamic>;
    }

    return records;
  }

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

  /// 4-Tier Mandi Retrieval Algorithm matching mandi.py
  Future<MandiResponse> fetchPrices({
    required String state,
    required String district,
    required String commodity,
  }) async {
    final userCoords = getLocationCoords(state, district);

    // 1. Fetch District Level Records
    final districtRaw = await _fetchRecords({
      'filters[state]': state,
      'filters[district]': district,
    }, maxRecords: 100);
    final districtCropMatches = await _filterCommodity(districtRaw, commodity);

    // 2. Fetch State Level Records
    final stateRaw = await _fetchRecords({
      'filters[state]': state,
    }, maxRecords: 100);
    final stateCropMatches = await _filterCommodity(stateRaw, commodity);

    // 3. Fetch All-India Records for commodity & synonyms
    final searchTerms = getSearchTerms(commodity);
    final allIndiaRaw = <dynamic>[];
    for (final sterm in searchTerms.take(3)) {
      final recs = await _fetchRecords({'filters[commodity]': sterm}, maxRecords: 50);
      allIndiaRaw.addAll(recs);
    }
    final allIndiaCropMatches = await _filterCommodity(allIndiaRaw, commodity);

    // Combine all raw matches
    final combinedRaw = [...districtCropMatches, ...stateCropMatches, ...allIndiaCropMatches];

    final processedMandis = <MandiPriceRecord>[];
    final seenKeys = <String>{};

    for (final r in combinedRaw) {
      if (r is! Map) continue;
      final jsonMap = Map<String, dynamic>.from(r);

      final mState = jsonMap['state']?.toString() ?? state;
      final mDistrict = jsonMap['district']?.toString() ?? district;
      final marketName = jsonMap['market']?.toString() ?? 'Local Mandi';
      final key = "$mState:$mDistrict:$marketName";

      if (seenKeys.contains(key)) continue;

      final modalP = _safeDouble(jsonMap['modal_price_quintal'] ?? jsonMap['modal_price']);
      final minP = _safeDouble(jsonMap['min_price_quintal'] ?? jsonMap['min_price'], modalP);
      final maxP = _safeDouble(jsonMap['max_price_quintal'] ?? jsonMap['max_price'], modalP);

      var effectiveModal = modalP;
      if (effectiveModal <= 0 && maxP > 0) effectiveModal = maxP;
      if (effectiveModal <= 0 && minP > 0) effectiveModal = minP;

      if (effectiveModal > 0) {
        seenKeys.add(key);
        final mCoords = getLocationCoords(mState, mDistrict);
        final distKm = haversine(userCoords[0], userCoords[1], mCoords[0], mCoords[1]);

        final isSameDistrict = (mDistrict.toLowerCase().contains(district.toLowerCase()) ||
                district.toLowerCase().contains(mDistrict.toLowerCase())) &&
            (mState.toLowerCase() == state.toLowerCase());
        final isSameState = (mState.toLowerCase() == state.toLowerCase());

        final rawRecord = MandiPriceRecord.fromJson(jsonMap, district, state, commodity);
        processedMandis.add(
          MandiPriceRecord(
            market: rawRecord.market,
            district: rawRecord.district,
            state: rawRecord.state,
            commodity: rawRecord.commodity,
            variety: rawRecord.variety,
            grade: rawRecord.grade,
            modalPriceQuintal: effectiveModal,
            modalPriceKg: _safeDouble((effectiveModal / 100.0).toStringAsFixed(2)),
            minPriceQuintal: minP > 0 ? minP : effectiveModal,
            minPriceKg: _safeDouble(((minP > 0 ? minP : effectiveModal) / 100.0).toStringAsFixed(2)),
            maxPriceQuintal: maxP > 0 ? maxP : effectiveModal,
            maxPriceKg: _safeDouble(((maxP > 0 ? maxP : effectiveModal) / 100.0).toStringAsFixed(2)),
            arrivalDate: rawRecord.arrivalDate,
            distanceKm: _safeDouble(distKm.toStringAsFixed(1)),
            isSameDistrict: isSameDistrict,
            isSameState: isSameState,
          ),
        );
      }
    }

    // Sort all mandis strictly by geographic distance
    processedMandis.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // SECTION 1: Selected District Mandis
    final districtMandis = processedMandis.where((m) => m.isSameDistrict).toList();

    // Active district market summary for other crops if selected crop is not in selected district today
    final activeDistrictOtherCrops = <MandiPriceRecord>[];
    if (districtMandis.isEmpty) {
      final seenDMk = <String>{};
      for (final r in districtRaw) {
        if (r is! Map) continue;
        final jsonMap = Map<String, dynamic>.from(r);
        final mk = jsonMap['market']?.toString() ?? 'Local Mandi';
        if (seenDMk.contains(mk)) continue;

        final mp = _safeDouble(jsonMap['modal_price_quintal'] ?? jsonMap['modal_price']) > 0
            ? _safeDouble(jsonMap['modal_price_quintal'] ?? jsonMap['modal_price'])
            : _safeDouble(jsonMap['max_price_quintal'] ?? jsonMap['max_price']);

        if (mp > 0) {
          seenDMk.add(mk);
          activeDistrictOtherCrops.add(
            MandiPriceRecord(
              market: mk,
              district: jsonMap['district']?.toString() ?? district,
              state: jsonMap['state']?.toString() ?? state,
              commodity: jsonMap['commodity']?.toString() ?? 'Other Crop',
              variety: jsonMap['variety']?.toString() ?? 'Standard',
              grade: jsonMap['grade']?.toString() ?? 'Grade A',
              modalPriceQuintal: mp,
              modalPriceKg: _safeDouble((mp / 100.0).toStringAsFixed(2)),
              minPriceQuintal: mp,
              minPriceKg: _safeDouble((mp / 100.0).toStringAsFixed(2)),
              maxPriceQuintal: mp,
              maxPriceKg: _safeDouble((mp / 100.0).toStringAsFixed(2)),
              arrivalDate: jsonMap['arrival_date']?.toString() ?? 'Latest',
              distanceKm: 0.0,
              isSameDistrict: true,
              isSameState: true,
            ),
          );
        }
      }
    }

    // SECTION 2: Selected State Mandis (excluding district mandis)
    final stateMandis = processedMandis.where((m) => m.isSameState && !m.isSameDistrict).toList();

    // SECTION 3: Single Best Mandi Choice overall
    MandiPriceRecord? bestMandi;
    if (processedMandis.isNotEmpty) {
      if (districtMandis.isNotEmpty) {
        districtMandis.sort((a, b) => b.modalPriceQuintal.compareTo(a.modalPriceQuintal));
        final topDist = districtMandis.first;
        bestMandi = topDist.copyWithReason(
          "⭐ Top Mandi in $district District (Best Local Price: ₹${topDist.modalPriceQuintal.toStringAsFixed(0)}/qtn)",
        );
      } else if (stateMandis.isNotEmpty) {
        final topNearby = stateMandis.take(3).toList();
        topNearby.sort((a, b) => b.modalPriceQuintal.compareTo(a.modalPriceQuintal));
        final topState = topNearby.first;
        bestMandi = topState.copyWithReason(
          "⭐ Best Mandi Choice in $state (Top price nearby: ₹${topState.modalPriceQuintal.toStringAsFixed(0)}/qtn • ${topState.distanceKm} km)",
        );
      } else {
        final topAll = processedMandis.take(3).toList();
        topAll.sort((a, b) => b.modalPriceQuintal.compareTo(a.modalPriceQuintal));
        final topOverall = topAll.first;
        bestMandi = topOverall.copyWithReason(
          "⭐ Best Mandi Choice Nearest to $district (Highest price: ₹${topOverall.modalPriceQuintal.toStringAsFixed(0)}/qtn • ${topOverall.distanceKm} km away)",
        );
      }
    }

    // SECTION 4: Remaining Mandis (Other states/regions)
    final remainingMandis = processedMandis.where((m) => !m.isSameState).toList();

    return MandiResponse(
      queryState: state,
      queryDistrict: district,
      queryCommodity: commodity,
      districtMandis: districtMandis,
      activeDistrictOtherCrops: activeDistrictOtherCrops,
      stateMandis: stateMandis,
      bestMandi: bestMandi,
      remainingMandis: remainingMandis,
      allMandis: processedMandis,
    );
  }
}
