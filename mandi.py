import os
import json
import time
import math
import urllib.request
import urllib.parse
import urllib.error
# pyrefly: ignore [missing-import]
from flask import Flask, jsonify, request, render_template_string

app = Flask(__name__)

# OGD India Mandi Price API Configuration
API_KEY = "579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b"
RESOURCE_ID = "9ef84268-d588-465a-a308-a864a43d0070"
BASE_URL = f"https://api.data.gov.in/resource/{RESOURCE_ID}"

# In-Memory Cache to prevent HTTP 429 Rate Limits from data.gov.in
API_CACHE = {}
CACHE_TTL = 300  # 5 minutes cache

def fetch_data_gov_records(params, max_records=100):
    """Helper function to execute HTTP request to data.gov.in Mandi API with retry backoff, pagination, throttling, and caching."""
    query_str = urllib.parse.urlencode(sorted(params.items()))
    cache_key = f"{query_str}_max{max_records}"
    now = time.time()

    # Return cached data if valid
    if cache_key in API_CACHE:
        cached_time, cached_records = API_CACHE[cache_key]
        if now - cached_time < CACHE_TTL and len(cached_records) > 0:
            return cached_records

    records = []
    offset = 0
    page_size = 10  # data.gov.in API page limit
    total = 0

    while offset < max_records:
        current_params = params.copy()
        current_params["offset"] = offset
        current_params["limit"] = page_size
        q_str = urllib.parse.urlencode(sorted(current_params.items()))
        url = f"{BASE_URL}?api-key={API_KEY}&format=json&{q_str}"
        
        page_recs = None
        for attempt in range(2):  # Retry up to 2 times with exponential delay on HTTP 429 rate limit
            try:
                req = urllib.request.Request(
                    url, 
                    headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MandiPriceApp/1.0"}
                )
                with urllib.request.urlopen(req, timeout=10) as response:
                    data = json.loads(response.read().decode("utf-8"))
                    page_recs = data.get("records", [])
                    total = data.get("total", 0)
                    break
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    time.sleep(0.5 * (attempt + 1))
                else:
                    break
            except Exception:
                break
        
        if page_recs is None or not page_recs:
            break
            
        records.extend(page_recs)
        offset += len(page_recs)
        if offset >= total:
            break
        time.sleep(0.2)  # 200ms throttle between paginated requests

    if records:
        API_CACHE[cache_key] = (now, records)
    elif cache_key in API_CACHE:
        records = API_CACHE[cache_key][1]

    return records

# Crop Synonyms and Vernacular Alias Mapping
CROP_ALIASES = {
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
}

def get_search_terms(search_crop):
    """Expand input crop into synonymous government mandi commodity names."""
    crop_term = search_crop.strip().lower()
    terms = [crop_term]
    for key, aliases in CROP_ALIASES.items():
        if key == crop_term or key in crop_term or crop_term in key:
            terms.extend(aliases)
    return list(set(terms))

def match_commodity_records(records, search_crop):
    """Case-insensitive fuzzy and synonym matching for crop names."""
    if not records or not search_crop:
        return []
    terms = get_search_terms(search_crop)
    matched = []
    for r in records:
        cm = r.get("commodity", "").strip().lower()
        if not cm:
            continue
        for term in terms:
            if term == cm or term in cm or cm in term:
                matched.append(r)
                break
    return matched

# State Capital / Center Coordinates
STATE_CENTER_COORDINATES = {
    "Andhra Pradesh": (15.9129, 79.7400),
    "Arunachal Pradesh": (28.2180, 94.7278),
    "Assam": (26.2006, 92.9376),
    "Bihar": (25.0961, 85.3131),
    "Chhattisgarh": (21.2787, 81.8661),
    "Chattisgarh": (21.2787, 81.8661),
    "Goa": (15.2993, 74.1240),
    "Gujarat": (22.2587, 71.1924),
    "Haryana": (29.0588, 76.0856),
    "Himachal Pradesh": (31.1048, 77.1734),
    "Jammu and Kashmir": (33.7782, 76.5762),
    "Jharkhand": (23.6102, 85.2799),
    "Karnataka": (15.3173, 75.7139),
    "Kerala": (10.8505, 76.2711),
    "Madhya Pradesh": (22.9734, 78.6569),
    "Maharashtra": (19.7515, 75.7139),
    "Manipur": (24.6637, 93.9063),
    "Meghalaya": (25.4670, 91.3662),
    "Mizoram": (23.1645, 92.9376),
    "Nagaland": (26.1584, 94.5624),
    "Odisha": (20.9517, 85.0985),
    "Punjab": (31.1471, 75.3412),
    "Rajasthan": (27.0238, 74.2179),
    "Sikkim": (27.5330, 88.5122),
    "Tamil Nadu": (11.1271, 78.6569),
    "Telangana": (18.1124, 79.0193),
    "Tripura": (23.9408, 91.9882),
    "Uttar Pradesh": (26.8467, 80.9462),
    "Uttarakhand": (30.0668, 79.0193),
    "West Bengal": (22.9868, 87.8550)
}

# Major District Coordinates (Latitude, Longitude) for accurate distance calculation
DISTRICT_COORDINATES = {
    # Karnataka
    ("Karnataka", "Davanagere"): (14.4674, 75.9241),
    ("Karnataka", "Davangere"): (14.4674, 75.9241),
    ("Karnataka", "Bengaluru Urban"): (12.9716, 77.5946),
    ("Karnataka", "Bengaluru Rural"): (13.2257, 77.5750),
    ("Karnataka", "Bengaluru South"): (12.9141, 77.5855),
    ("Karnataka", "Shivamogga"): (13.9299, 75.5681),
    ("Karnataka", "Chamarajanagar"): (11.9261, 76.9437),
    ("Karnataka", "Belagavi"): (15.8497, 74.4977),
    ("Karnataka", "Ballari"): (15.1394, 76.9214),
    ("Karnataka", "Kalaburagi"): (17.3297, 76.8343),
    ("Karnataka", "Ramanagara"): (12.7214, 77.2814),
    ("Karnataka", "Chitradurga"): (14.2251, 76.3980),
    ("Karnataka", "Hassan"): (13.0072, 76.1011),
    ("Karnataka", "Mandya"): (12.5218, 76.8951),
    ("Karnataka", "Mysuru"): (12.2958, 76.6394),
    ("Karnataka", "Tumakuru"): (13.3379, 77.1173),
    ("Karnataka", "Dharwad"): (15.4589, 75.0078),
    ("Karnataka", "Bagalkot"): (16.1852, 75.6961),
    ("Karnataka", "Bidar"): (17.9104, 77.5199),
    ("Karnataka", "Chikkamagaluru"): (13.3153, 75.7754),
    ("Karnataka", "Dakshina Kannada"): (12.8702, 74.8806),
    ("Karnataka", "Gadag"): (15.4317, 75.6355),
    ("Karnataka", "Haveri"): (14.7954, 75.3992),
    ("Karnataka", "Kolar"): (13.1367, 78.1291),
    ("Karnataka", "Koppal"): (15.3519, 76.1553),
    ("Karnataka", "Raichur"): (16.2076, 77.3463),
    ("Karnataka", "Udupi"): (13.3409, 74.7421),
    ("Karnataka", "Uttara Kannada"): (14.8185, 74.1416),
    ("Karnataka", "Yadgir"): (16.7700, 77.1378),

    # Maharashtra
    ("Maharashtra", "Kolhapur"): (16.7050, 74.2433),
    ("Maharashtra", "Sangli"): (16.8524, 74.5815),
    ("Maharashtra", "Solapur"): (17.6599, 75.9064),
    ("Maharashtra", "Satara"): (17.6805, 74.0183),
    ("Maharashtra", "Pune"): (18.5204, 73.8567),
    ("Maharashtra", "Nashik"): (19.9975, 73.7898),
    ("Maharashtra", "Chattrapati Sambhajinagar"): (19.8762, 75.3433),
    ("Maharashtra", "Aurangabad"): (19.8762, 75.3433),
    ("Maharashtra", "Jalna"): (19.8410, 75.8864),
    ("Maharashtra", "Akola"): (20.7002, 77.0082),
    ("Maharashtra", "Ahilyanagar"): (19.0948, 74.7480),
    ("Maharashtra", "Ahmednagar"): (19.0948, 74.7480),
    ("Maharashtra", "Latur"): (18.4088, 76.5604),
    ("Maharashtra", "Nanded"): (19.1383, 77.3210),

    # Madhya Pradesh
    ("Madhya Pradesh", "Badwani"): (22.0354, 74.9048),
    ("Madhya Pradesh", "Barwani"): (22.0354, 74.9048),
    ("Madhya Pradesh", "Indore"): (22.7196, 75.8577),
    ("Madhya Pradesh", "Harda"): (22.3394, 77.0967),
    ("Madhya Pradesh", "Sehore"): (23.2031, 77.0845),
    ("Madhya Pradesh", "Sagar"): (23.8388, 78.7378),
    ("Madhya Pradesh", "Shajapur"): (23.4277, 76.2773),

    # Telangana
    ("Telangana", "Hyderabad"): (17.3850, 78.4867),
    ("Telangana", "Nizamabad"): (18.6725, 78.0941),
    ("Telangana", "Mahabubnagar"): (16.7488, 77.9942),

    # Andhra Pradesh
    ("Andhra Pradesh", "NTR"): (16.5062, 80.6480),
    ("Andhra Pradesh", "Guntur"): (16.3067, 80.4365),
    ("Andhra Pradesh", "Chittoor"): (13.2172, 79.1003),
    ("Andhra Pradesh", "Anantapur"): (14.6819, 77.6006),

    # Kerala
    ("Kerala", "Ernakulam"): (9.9816, 76.2999),
    ("Kerala", "Palakkad"): (10.7867, 76.6548),
    ("Kerala", "Thrissur"): (10.5276, 76.2144),

    # Gujarat
    ("Gujarat", "Dahod"): (22.8347, 74.2543),
    ("Gujarat", "Surat"): (21.1702, 72.8311),
    ("Gujarat", "Rajkot"): (22.3039, 70.8022),
    ("Gujarat", "Ahmedabad"): (23.0225, 72.5714),

    # Uttar Pradesh
    ("Uttar Pradesh", "Agra"): (27.1767, 78.0081),
    ("Uttar Pradesh", "Azamgarh"): (26.0682, 83.1843),
    ("Uttar Pradesh", "Lalitpur"): (24.6896, 78.4120),
    ("Uttar Pradesh", "Lucknow"): (26.8467, 80.9462),
    ("Uttar Pradesh", "Kanpur Nagar"): (26.4499, 80.3319)
}

def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two lat/lon coordinates."""
    R = 6371.0 # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def get_location_coords(state, district):
    """Retrieve coordinates for state/district with fallback to state center."""
    if (state, district) in DISTRICT_COORDINATES:
        return DISTRICT_COORDINATES[(state, district)]
    for (s, d), coords in DISTRICT_COORDINATES.items():
        if s.lower() == state.lower() and (d.lower() in district.lower() or district.lower() in d.lower()):
            return coords
    return STATE_CENTER_COORDINATES.get(state, (20.5937, 78.9629))

# Comprehensive Master Data of Indian States and Districts
INDIAN_STATES_DISTRICTS = {
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
    "Uttar Pradesh": ["Agra", "Aligarh", "Ambedkar Nagar", "Amethi", "Amroha", "Auraiya", "Ayodhya", "Azamgarh", "Badaun", "Baghpat", "Bahraich", "Ballia", "Balrampur", "Banda", "Barabanki", "Bareilly", "Basti", "Bhajnoi", "Bijnor", "Bulandshahr", "Chandauli", "Chitrakoot", "Deoria", "Etah", "Etawah", "Farrukhabad", "Fatehpur", "Firozabad", "Gautam Buddha Nagar", "Ghaziabad", "Ghazipur", "Gonda", "Gorakhpur", "Hamirpur", "Hapur", "Hardoi", "Hathras", "Jalaun", "Jaunpur", "Jhansi", "Kannauj", "Kanpur Dehat", "Kanpur Nagar", "Kasganj", "Kaushambi", "Kheri", "Kushinagar", "Lalitpur", "Lucknow", "Maharajganj", "Mahoba", "Mainpuri", "Mathura", "Mau", "Meerut", "Mirzapur", "Moradabad", "Muzaffarnagar", "Pilibhit", "Pratapgarh", "Prayagraj", "Rae Bareli", "Rampur", "Saharanpur", "Sambhal", "Sant Kabir Nagar", "Shahjahanpur", "Shamli", "Shravasti", "Siddharthnagar", "Sitapur", "Sonbhadra", "Sultanpur", "Unnao", "Varanasi"],
    "Uttarakhand": ["Almora", "Bageshwar", "Chamoli", "Champawat", "Dehradun", "Haridwar", "Nainital", "Pauri Garhwal", "Pithoragarh", "Rudraprayag", "Tehri Garhwal", "Udham Singh Nagar", "Uttarkashi"],
    "West Bengal": ["Alipurduar", "Bankura", "Birbhum", "Cooch Behar", "Dakshin Dinajpur", "Darjeeling", "Hooghly", "Howrah", "Jalpaiguri", "Jhargram", "Kalimpong", "Kolkata", "Malda", "Murshidabad", "Nadia", "North 24 Parganas", "Paschim Bardhaman", "Paschim Medinipur", "Purba Bardhaman", "Purba Medinipur", "Purulia", "South 24 Parganas", "Uttar Dinajpur"]
}

POPULAR_COMMODITIES = [
    "Apple", "Arecanut(Betelnut/Supari)", "Arhar (Tur/Red Gram)", "Ashgourd", "Bajra(Pearl Millet/Cumbu)", "Banana", "Banana - Green", 
    "Barley (Jau)", "Bengal Gram(Gram)(Whole)", "Bitter gourd", "Bhindi(Ladies Finger)", "Black Gram (Urd Beans)", 
    "Bottle gourd", "Brinjal", "Cabbage", "Capsicum", "Carrot", "Cauliflower", "Chili Red", "Chilli Green", 
    "Coconut", "Coriander(Leaves)", "Cotton", "Cucumber", "Cumin Seed(Jeera)", "Drumstick", "Fish", "Garlic", 
    "Ginger(Green)", "Grapes", "Green Gram (Moong)", "Groundnut", "Guava", "Jowar(Sorghum)", "Lemon", 
    "Maize", "Mango", "Mustard", "Onion", "Paddy(Dhan)(Common)", "Paddy(Dhan)(Basmati)", "Papaya", "Papaya(Raw)", "Peas(Dry)", "Peas wet", "Pomegranate", 
    "Potato", "Pumpkin", "Radish", "Ragi (Finger Millet)", "Rice", "Soyabean", "Spinach", "Sugarcane", 
    "Sweet Potato", "Tomato", "Turmeric", "Watermelon", "Wheat"
]

@app.route("/api/states", methods=["GET"])
def get_states():
    """Return all Indian states."""
    states = sorted(list(INDIAN_STATES_DISTRICTS.keys()))
    return jsonify({"status": "success", "states": states})

@app.route("/api/districts", methods=["GET"])
def get_districts():
    """Return districts for selected state."""
    state = request.args.get("state", "").strip()
    if not state or state not in INDIAN_STATES_DISTRICTS:
        return jsonify({"status": "error", "message": "Invalid state selected", "districts": []})
    
    districts = sorted(INDIAN_STATES_DISTRICTS[state])
    return jsonify({"status": "success", "state": state, "districts": districts})

@app.route("/api/commodities", methods=["GET"])
def get_commodities():
    """Return all pre-loaded commodities for dropdown selection."""
    q = request.args.get("q", "").strip().lower()
    if not q:
        return jsonify({"status": "success", "commodities": sorted(POPULAR_COMMODITIES)})
    
    matched = [c for c in POPULAR_COMMODITIES if q in c.lower()]
    return jsonify({"status": "success", "commodities": matched})

@app.route("/api/fetch-prices", methods=["GET"])
def fetch_prices():
    """
    4-Tier Structured API response:
    Section 1: Mandis in the SAME selected District & State.
    Section 2: Other Mandis in the SAME selected State.
    Section 3: The SINGLE BEST Mandi Choice overall (top modal price & distance).
    Section 4: REMAINING Mandis from other states/regions sorted by distance (km).
    """
    state = request.args.get("state", "").strip()
    district = request.args.get("district", "").strip()
    commodity = request.args.get("commodity", "").strip()

    if not state or not district or not commodity:
        return jsonify({
            "status": "error",
            "message": "State, District, and Crop selection are required."
        }), 400

    user_coords = get_location_coords(state, district)

    # 1. Fetch District Level Records
    district_raw = fetch_data_gov_records({
        "filters[state]": state,
        "filters[district]": district
    }, max_records=100)
    district_crop_matches = match_commodity_records(district_raw, commodity)

    # 2. Fetch State Level Records
    state_raw = fetch_data_gov_records({
        "filters[state]": state
    }, max_records=100)
    state_crop_matches = match_commodity_records(state_raw, commodity)

    # 3. Fetch All-India Records for commodity & synonyms
    search_terms = get_search_terms(commodity)
    all_india_raw = []
    for sterm in search_terms[:3]:
        recs = fetch_data_gov_records({"filters[commodity]": sterm}, max_records=50)
        all_india_raw.extend(recs)
    all_india_crop_matches = match_commodity_records(all_india_raw, commodity)

    # Combine all records
    combined_raw = district_crop_matches + state_crop_matches + all_india_crop_matches
    
    processed_mandis = []
    seen_keys = set()
    for r in combined_raw:
        m_state = r.get("state", state)
        m_district = r.get("district", district)
        market_name = r.get("market", "Local Mandi")
        key = (m_state, m_district, market_name)
        if key in seen_keys:
            continue

        try:
            modal_p = float(r.get("modal_price", 0))
            min_p = float(r.get("min_price", modal_p))
            max_p = float(r.get("max_price", modal_p))
        except (ValueError, TypeError):
            continue

        if modal_p <= 0 and max_p > 0: modal_p = max_p
        if modal_p <= 0 and min_p > 0: modal_p = min_p

        if modal_p > 0:
            seen_keys.add(key)
            m_coords = get_location_coords(m_state, m_district)
            dist_km = haversine(user_coords[0], user_coords[1], m_coords[0], m_coords[1])

            is_same_district = (m_district.lower() in district.lower() or district.lower() in m_district.lower()) and (m_state.lower() == state.lower())
            is_same_state = (m_state.lower() == state.lower())

            processed_mandis.append({
                "market": market_name,
                "district": m_district,
                "state": m_state,
                "commodity": r.get("commodity", commodity),
                "variety": r.get("variety", "Standard"),
                "grade": r.get("grade", "Grade A"),
                "modal_price_quintal": round(modal_p, 2),
                "modal_price_kg": round(modal_p / 100.0, 2),
                "min_price_quintal": round(min_p if min_p > 0 else modal_p, 2),
                "max_price_quintal": round(max_p if max_p > 0 else modal_p, 2),
                "arrival_date": r.get("arrival_date", "Latest"),
                "distance_km": round(dist_km, 1),
                "is_same_district": is_same_district,
                "is_same_state": is_same_state
            })

    # Sort all mandis strictly by geographic distance
    processed_mandis.sort(key=lambda x: x["distance_km"])

    # --- SECTION 1: Selected District Mandis ---
    district_mandis = [m for m in processed_mandis if m["is_same_district"]]
    
    # Active district market summary for other crops if selected crop is not in selected district today
    active_district_other_crops = []
    if not district_mandis:
        seen_d_mk = set()
        for r in district_raw:
            mk = r.get("market", "Local Mandi")
            if mk in seen_d_mk: continue
            seen_d_mk.add(mk)
            try:
                mp = float(r.get("modal_price", 0)) or float(r.get("max_price", 0))
                if mp > 0:
                    active_district_other_crops.append({
                        "market": mk,
                        "district": r.get("district", district),
                        "state": r.get("state", state),
                        "commodity": r.get("commodity", "Other Crop"),
                        "modal_price_quintal": round(mp, 2),
                        "arrival_date": r.get("arrival_date", "Latest"),
                        "distance_km": 0.0
                    })
            except (ValueError, TypeError):
                continue

    # --- SECTION 2: Selected State Mandis (excluding district mandis) ---
    state_mandis = [m for m in processed_mandis if m["is_same_state"] and not m["is_same_district"]]

    # --- SECTION 3: Single Best Mandi Choice ---
    best_mandi = None
    if processed_mandis:
        if district_mandis:
            best_mandi = max(district_mandis, key=lambda x: x["modal_price_quintal"])
            best_mandi_copy = dict(best_mandi)
            best_mandi_copy["reason"] = f"⭐ Top Mandi in {district} District (Best Local Price: ₹{best_mandi['modal_price_quintal']}/qtn)"
            best_mandi = best_mandi_copy
        elif state_mandis:
            top_nearby = state_mandis[:3]
            best_mandi = max(top_nearby, key=lambda x: x["modal_price_quintal"])
            best_mandi_copy = dict(best_mandi)
            best_mandi_copy["reason"] = f"⭐ Best Mandi Choice in {state} (Top price nearby: ₹{best_mandi['modal_price_quintal']}/qtn • {best_mandi['distance_km']} km)"
            best_mandi = best_mandi_copy
        else:
            top_all = processed_mandis[:3]
            best_mandi = max(top_all, key=lambda x: x["modal_price_quintal"])
            best_mandi_copy = dict(best_mandi)
            best_mandi_copy["reason"] = f"⭐ Best Mandi Choice Nearest to {district} (Highest price: ₹{best_mandi['modal_price_quintal']}/qtn • {best_mandi['distance_km']} km away)"
            best_mandi = best_mandi_copy

    # --- SECTION 4: Remaining Mandis (Other states/regions) ---
    remaining_mandis = [m for m in processed_mandis if not m["is_same_state"]]

    return jsonify({
        "status": "success",
        "query": {
            "state": state,
            "district": district,
            "commodity": commodity
        },
        "district_mandis": district_mandis,
        "active_district_other_crops": active_district_other_crops,
        "state_mandis": state_mandis,
        "best_mandi": best_mandi,
        "remaining_mandis": remaining_mandis,
        "all_mandis": processed_mandis
    })

# Embedded Modern HTML/CSS/JS Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>India Mandi Price Checker | Structured Mandi Intelligence</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Outfit:wght@500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-gradient: linear-gradient(135deg, #0f1f17 0%, #173322 50%, #0d2618 100%);
            --card-bg: rgba(255, 255, 255, 0.05);
            --card-border: rgba(255, 255, 255, 0.12);
            --card-hover: rgba(255, 255, 255, 0.08);
            --accent-green: #10b981;
            --accent-green-bright: #34d399;
            --accent-gold: #fbbf24;
            --accent-gold-bright: #f59e0b;
            --accent-blue: #38bdf8;
            --text-main: #f9fafb;
            --text-sub: #9ca3af;
            --text-muted: #6b7280;
            --radius-lg: 20px;
            --radius-md: 14px;
            --font-heading: 'Outfit', sans-serif;
            --font-body: 'Plus Jakarta Sans', sans-serif;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: var(--font-body);
            background: var(--bg-gradient);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 2rem 1rem;
        }

        .app-container {
            width: 100%;
            max-width: 960px;
            display: flex;
            flex-direction: column;
            gap: 2rem;
        }

        /* Header */
        header {
            text-align: center;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 0.75rem;
            padding: 1rem 0;
        }

        .badge-header {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(16, 185, 129, 0.15);
            border: 1px solid rgba(16, 185, 129, 0.3);
            color: var(--accent-green-bright);
            padding: 0.4rem 1rem;
            border-radius: 999px;
            font-size: 0.85rem;
            font-weight: 600;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }

        .pulse-dot {
            width: 8px;
            height: 8px;
            background: var(--accent-green-bright);
            border-radius: 50%;
            box-shadow: 0 0 10px var(--accent-green-bright);
            animation: pulse 1.8s infinite;
        }

        @keyframes pulse {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(52, 211, 153, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(52, 211, 153, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(52, 211, 153, 0); }
        }

        h1 {
            font-family: var(--font-heading);
            font-size: 2.5rem;
            font-weight: 800;
            background: linear-gradient(135deg, #ffffff 0%, #a7f3d0 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            line-height: 1.2;
        }

        p.subtitle {
            color: var(--text-sub);
            font-size: 1.05rem;
            max-width: 600px;
        }

        /* Input Form Card */
        .search-card {
            background: var(--card-bg);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--card-border);
            border-radius: var(--radius-lg);
            padding: 2rem;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
        }

        .form-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 1.25rem;
        }

        .input-group {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }

        label {
            font-size: 0.9rem;
            font-weight: 600;
            color: #d1d5db;
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }

        label span {
            color: var(--accent-gold);
        }

        select, input {
            width: 100%;
            padding: 0.85rem 1.1rem;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: var(--radius-md);
            color: #ffffff;
            font-family: var(--font-body);
            font-size: 0.95rem;
            outline: none;
            transition: all 0.25s ease;
        }

        select:focus, input:focus {
            border-color: var(--accent-green);
            background: rgba(0, 0, 0, 0.5);
            box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.2);
        }

        select option {
            background: #111827;
            color: #ffffff;
        }

        .btn-fetch {
            width: 100%;
            padding: 1.1rem;
            background: linear-gradient(135deg, #059669 0%, #10b981 100%);
            color: #ffffff;
            border: none;
            border-radius: var(--radius-md);
            font-family: var(--font-heading);
            font-size: 1.1rem;
            font-weight: 700;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.6rem;
            box-shadow: 0 10px 20px rgba(16, 185, 129, 0.3);
            transition: all 0.3s ease;
            margin-top: 0.5rem;
        }

        .btn-fetch:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 30px rgba(16, 185, 129, 0.4);
            background: linear-gradient(135deg, #047857 0%, #059669 100%);
        }

        .btn-fetch:active {
            transform: translateY(0);
        }

        .btn-fetch:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }

        /* Results Container */
        .results-container {
            display: flex;
            flex-direction: column;
            gap: 2rem;
            opacity: 0;
            transform: translateY(20px);
            transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .results-container.visible {
            opacity: 1;
            transform: translateY(0);
        }

        /* Section Headings */
        .section-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 0.75rem;
            flex-wrap: wrap;
            gap: 0.5rem;
        }

        .section-title {
            font-family: var(--font-heading);
            font-size: 1.35rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .tier-number {
            background: var(--accent-green);
            color: #000000;
            font-size: 0.8rem;
            font-weight: 800;
            width: 26px;
            height: 26px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .section-subtitle {
            font-size: 0.88rem;
            color: var(--accent-green-bright);
            background: rgba(52, 211, 153, 0.1);
            padding: 0.4rem 0.85rem;
            border-radius: 999px;
            border: 1px solid rgba(52, 211, 153, 0.25);
            font-weight: 600;
        }

        /* Mandi Item Card */
        .mandi-card-list {
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }

        .mandi-item-card {
            background: var(--card-bg);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--card-border);
            border-left: 5px solid var(--accent-green-bright);
            border-radius: var(--radius-lg);
            padding: 1.5rem;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }

        .mandi-item-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 0.5rem;
        }

        .mandi-name-badge {
            font-family: var(--font-heading);
            font-size: 1.25rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .mandi-location-tag {
            font-size: 0.85rem;
            color: var(--accent-green-bright);
            background: rgba(52, 211, 153, 0.12);
            border: 1px solid rgba(52, 211, 153, 0.25);
            padding: 0.3rem 0.75rem;
            border-radius: 999px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .distance-pill {
            background: rgba(56, 189, 248, 0.15);
            border: 1px solid rgba(56, 189, 248, 0.3);
            color: var(--accent-blue);
            padding: 0.2rem 0.6rem;
            border-radius: 999px;
            font-size: 0.8rem;
            font-weight: 700;
        }

        .district-local-pill {
            background: rgba(16, 185, 129, 0.2);
            border: 1px solid rgba(16, 185, 129, 0.4);
            color: var(--accent-green-bright);
            padding: 0.2rem 0.65rem;
            border-radius: 999px;
            font-size: 0.8rem;
            font-weight: 700;
        }

        .price-display-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1.25rem;
            background: rgba(0, 0, 0, 0.25);
            padding: 1.25rem;
            border-radius: var(--radius-md);
            border: 1px solid rgba(255, 255, 255, 0.05);
        }

        .price-box {
            display: flex;
            flex-direction: column;
            gap: 0.2rem;
        }

        .price-label {
            font-size: 0.85rem;
            color: var(--text-sub);
            font-weight: 500;
        }

        .price-main {
            font-family: var(--font-heading);
            font-size: 2.1rem;
            font-weight: 800;
            line-height: 1;
        }

        .mandi-item-card .price-main { color: #6ee7b7; }
        .best-card .price-main { color: #fde047; }

        .price-sub {
            font-size: 0.95rem;
            font-weight: 600;
            color: #e5e7eb;
        }

        .meta-list {
            display: flex;
            flex-wrap: wrap;
            gap: 1.25rem;
            font-size: 0.88rem;
            color: var(--text-sub);
            padding-top: 0.5rem;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
        }

        .meta-item {
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }

        .meta-item strong {
            color: #ffffff;
        }

        /* Best Mandi Hero Card */
        .best-card {
            background: var(--card-bg);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 2px solid var(--accent-gold);
            background: linear-gradient(135deg, rgba(251, 191, 36, 0.08) 0%, rgba(16, 185, 129, 0.04) 100%);
            border-radius: var(--radius-lg);
            padding: 1.75rem;
            box-shadow: 0 15px 35px rgba(251, 191, 36, 0.15);
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
        }

        .best-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
            color: #ffffff;
            padding: 0.4rem 1rem;
            border-radius: 999px;
            font-size: 0.85rem;
            font-weight: 800;
            letter-spacing: 0.5px;
            box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
            align-self: flex-start;
        }

        .reason-box {
            background: rgba(251, 191, 36, 0.12);
            border: 1px solid rgba(251, 191, 36, 0.3);
            color: #fef08a;
            padding: 0.75rem 1rem;
            border-radius: var(--radius-md);
            font-size: 0.95rem;
            font-weight: 600;
        }

        /* Loading Spinner */
        .spinner {
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: #ffffff;
            animation: spin 0.8s linear infinite;
            display: none;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .alert-box {
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #fca5a5;
            padding: 1.25rem;
            border-radius: var(--radius-md);
            font-size: 0.95rem;
            display: none;
        }

        footer {
            text-align: center;
            color: var(--text-muted);
            font-size: 0.85rem;
            margin-top: 2rem;
        }

        footer a {
            color: var(--accent-green-bright);
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="app-container">
        <!-- Header -->
        <header>
            <div class="badge-header">
                <div class="pulse-dot"></div>
                Live Mandi Prices • Ranked Order
            </div>
            <h1>Harvested Crop Price Intelligence</h1>
            <p class="subtitle">Search results ordered strictly: 1. District Mandis, 2. State Mandis, 3. Best Mandi Choice, 4. Remaining Mandis.</p>
        </header>

        <!-- Search Form Card -->
        <div class="search-card">
            <div class="form-grid">
                <!-- State Selection -->
                <div class="input-group">
                    <label for="stateSelect">State <span>*</span></label>
                    <select id="stateSelect">
                        <option value="">-- Select State --</option>
                    </select>
                </div>

                <!-- District Selection -->
                <div class="input-group">
                    <label for="districtSelect">District <span>*</span></label>
                    <select id="districtSelect" disabled>
                        <option value="">-- Select State First --</option>
                    </select>
                </div>

                <!-- Harvested Crop Dropdown Selection -->
                <div class="input-group">
                    <label for="cropSelect">Harvested Crop <span>*</span></label>
                    <select id="cropSelect">
                        <option value="">-- Select Crop --</option>
                    </select>
                    <input type="text" id="customCropInput" placeholder="Enter custom crop name..." style="display: none; margin-top: 0.5rem;">
                </div>
            </div>

            <button class="btn-fetch" id="fetchBtn">
                <div class="spinner" id="btnSpinner"></div>
                <span id="btnText">Fetch Mandi Results</span>
            </button>
        </div>

        <div class="alert-box" id="alertBox"></div>

        <!-- Ordered Results Display Container -->
        <div class="results-container" id="resultsContainer">
            
            <!-- SECTION 1: Mandis in Selected District -->
            <div class="section-group">
                <div class="section-header">
                    <div class="section-title">
                        <div class="tier-number">1</div>
                        📍 Mandis in Selected District
                    </div>
                    <div class="section-subtitle" id="sec1DistrictSubtitle">District</div>
                </div>

                <div class="mandi-card-list" id="sec1DistrictList"></div>
            </div>

            <!-- SECTION 2: Mandis in Selected State -->
            <div class="section-group">
                <div class="section-header">
                    <div class="section-title">
                        <div class="tier-number" style="background: var(--accent-blue); color: #000;">2</div>
                        🏛️ Mandis in Selected State
                    </div>
                    <div class="section-subtitle" id="sec2StateSubtitle" style="color: var(--accent-blue); border-color: rgba(56, 189, 248, 0.3);">State</div>
                </div>

                <div class="mandi-card-list" id="sec2StateList"></div>
            </div>

            <!-- SECTION 3: Best Mandi Choice -->
            <div class="section-group">
                <div class="section-header">
                    <div class="section-title" style="color: var(--accent-gold);">
                        <div class="tier-number" style="background: var(--accent-gold); color: #000;">3</div>
                        ⭐ Best Mandi Choice
                    </div>
                </div>

                <div class="best-card" id="sec3BestCard">
                    <div class="best-badge">⭐ RECOMMENDED BEST MANDI CHOICE</div>
                    
                    <div class="mandi-item-header">
                        <div class="mandi-name-badge" id="bestMarketName">Mandi Name</div>
                        <div class="mandi-location-tag" id="bestLocationTag">📍 District, State</div>
                    </div>

                    <div class="reason-box" id="bestReasonText">
                        Reason why this mandi is recommended
                    </div>

                    <div class="price-display-grid">
                        <div class="price-box">
                            <div class="price-label">Modal Price (Quintal)</div>
                            <div class="price-main" id="bestQuintalPrice">₹0</div>
                            <div class="price-sub">per Quintal (100 kg)</div>
                        </div>
                        <div class="price-box">
                            <div class="price-label">Converted Price per Kg</div>
                            <div class="price-main" id="bestKgPrice">₹0</div>
                            <div class="price-sub">per Kilogram</div>
                        </div>
                    </div>

                    <div class="meta-list">
                        <div class="meta-item">Crop: <strong id="bestCropName">-</strong></div>
                        <div class="meta-item">Min Price: <strong id="bestMinPrice">₹0/qtn</strong></div>
                        <div class="meta-item">Max Price: <strong id="bestMaxPrice">₹0/qtn</strong></div>
                        <div class="meta-item">Variety: <strong id="bestVariety">Standard</strong></div>
                        <div class="meta-item">Date: <strong id="bestDate">Latest</strong></div>
                    </div>
                </div>
            </div>

            <!-- SECTION 4: Remaining Mandis (All India / Neighboring States) -->
            <div class="section-group">
                <div class="section-header">
                    <div class="section-title">
                        <div class="tier-number" style="background: #9ca3af; color: #000;">4</div>
                        🌐 Remaining Mandi Results (Ranked by Distance)
                    </div>
                </div>

                <div class="mandi-card-list" id="sec4RemainingList"></div>
            </div>

        </div>

        <footer>
            Data source: <a href="https://data.gov.in" target="_blank">Open Government Data (OGD) Platform India</a> • Ministry of Agriculture & Farmers Welfare
        </footer>
    </div>

    <script>
        // DOM Elements
        const stateSelect = document.getElementById('stateSelect');
        const districtSelect = document.getElementById('districtSelect');
        const cropSelect = document.getElementById('cropSelect');
        const customCropInput = document.getElementById('customCropInput');
        const fetchBtn = document.getElementById('fetchBtn');
        const btnSpinner = document.getElementById('btnSpinner');
        const btnText = document.getElementById('btnText');
        const alertBox = document.getElementById('alertBox');
        const resultsContainer = document.getElementById('resultsContainer');

        const sec1DistrictSubtitle = document.getElementById('sec1DistrictSubtitle');
        const sec1DistrictList = document.getElementById('sec1DistrictList');

        const sec2StateSubtitle = document.getElementById('sec2StateSubtitle');
        const sec2StateList = document.getElementById('sec2StateList');

        const bestMarketName = document.getElementById('bestMarketName');
        const bestLocationTag = document.getElementById('bestLocationTag');
        const bestReasonText = document.getElementById('bestReasonText');
        const bestQuintalPrice = document.getElementById('bestQuintalPrice');
        const bestKgPrice = document.getElementById('bestKgPrice');
        const bestCropName = document.getElementById('bestCropName');
        const bestMinPrice = document.getElementById('bestMinPrice');
        const bestMaxPrice = document.getElementById('bestMaxPrice');
        const bestVariety = document.getElementById('bestVariety');
        const bestDate = document.getElementById('bestDate');

        const sec4RemainingList = document.getElementById('sec4RemainingList');

        // Initial Setup
        document.addEventListener('DOMContentLoaded', () => {
            loadStates();
            loadCommoditiesDropdown();
        });

        // Fetch States List
        async function loadStates() {
            try {
                const res = await fetch('/api/states');
                const data = await res.json();
                if (data.status === 'success') {
                    stateSelect.innerHTML = '<option value="">-- Select State --</option>';
                    data.states.forEach(st => {
                        const opt = document.createElement('option');
                        opt.value = st;
                        opt.textContent = st;
                        stateSelect.appendChild(opt);
                    });
                }
            } catch (err) {
                showAlert('Failed to load Indian states. Please refresh page.');
            }
        }

        // Handle State Change -> Update Districts Dropdown Automatically
        stateSelect.addEventListener('change', async () => {
            const selectedState = stateSelect.value;
            districtSelect.innerHTML = '<option value="">-- Select District --</option>';
            
            if (!selectedState) {
                districtSelect.disabled = true;
                districtSelect.innerHTML = '<option value="">-- Select State First --</option>';
                return;
            }

            districtSelect.disabled = false;
            try {
                const res = await fetch(`/api/districts?state=${encodeURIComponent(selectedState)}`);
                const data = await res.json();
                if (data.status === 'success') {
                    data.districts.forEach(dt => {
                        const opt = document.createElement('option');
                        opt.value = dt;
                        opt.textContent = dt;
                        districtSelect.appendChild(opt);
                    });
                }
            } catch (err) {
                showAlert('Failed to load districts for selected state.');
            }
        });

        // Populate Harvested Crop Select Dropdown
        async function loadCommoditiesDropdown() {
            try {
                const res = await fetch('/api/commodities');
                const data = await res.json();
                if (data.status === 'success') {
                    cropSelect.innerHTML = '<option value="">-- Select Harvested Crop --</option>';
                    data.commodities.forEach(cm => {
                        const opt = document.createElement('option');
                        opt.value = cm;
                        opt.textContent = cm;
                        cropSelect.appendChild(opt);
                    });
                    const customOpt = document.createElement('option');
                    customOpt.value = "__OTHER__";
                    customOpt.textContent = "✏️ Other (Type Custom Crop)";
                    cropSelect.appendChild(customOpt);
                }
            } catch (err) {
                console.error(err);
            }
        }

        // Handle Crop Dropdown Change
        cropSelect.addEventListener('change', () => {
            if (cropSelect.value === '__OTHER__') {
                customCropInput.style.display = 'block';
                customCropInput.focus();
            } else {
                customCropInput.style.display = 'none';
            }
        });

        // Get Selected Crop Value
        function getSelectedCrop() {
            if (cropSelect.value === '__OTHER__') {
                return customCropInput.value.trim();
            }
            return cropSelect.value.trim();
        }

        // Handle Fetch Button Click
        fetchBtn.addEventListener('click', async () => {
            const state = stateSelect.value;
            const district = districtSelect.value;
            const crop = getSelectedCrop();

            if (!state || !district || !crop) {
                showAlert('Please select State, District, and your Harvested Crop.');
                return;
            }

            hideAlert();
            setLoading(true);

            try {
                const url = `/api/fetch-prices?state=${encodeURIComponent(state)}&district=${encodeURIComponent(district)}&commodity=${encodeURIComponent(crop)}`;
                const res = await fetch(url);
                const data = await res.json();

                if (data.status === 'error') {
                    showAlert(data.message || 'Error fetching Mandi prices.');
                    setLoading(false);
                    return;
                }

                if ((!data.all_mandis || data.all_mandis.length === 0) && (!data.district_mandis || data.district_mandis.length === 0)) {
                    showAlert(`No Mandi price records found for "${crop}".`);
                    setLoading(false);
                    return;
                }

                renderOrderedResults(data, crop, district, state);
            } catch (err) {
                showAlert('Network error while querying Mandi price API. Please try again.');
            } finally {
                setLoading(false);
            }
        });

        function renderOrderedResults(data, crop, district, state) {
            const dMandis = data.district_mandis || [];
            const otherDistrictCrops = data.active_district_other_crops || [];
            const sMandis = data.state_mandis || [];
            const best = data.best_mandi;
            const rMandis = data.remaining_mandis || [];

            // SECTION 1: DISTRICT MANDIS
            sec1DistrictSubtitle.textContent = `${district}, ${state}`;
            sec1DistrictList.innerHTML = '';

            if (dMandis.length > 0) {
                dMandis.forEach(mandi => {
                    sec1DistrictList.appendChild(createMandiCard(mandi));
                });
            } else if (otherDistrictCrops.length > 0) {
                const noticeCard = document.createElement('div');
                noticeCard.className = 'mandi-item-card';
                noticeCard.style.borderLeftColor = 'var(--accent-gold)';
                noticeCard.innerHTML = `
                    <div class="mandi-name-badge" style="font-size: 1.05rem; color: #fef08a;">
                        ⚠️ No active "${crop}" trades reported in ${district} today. Showing active ${district} Mandi markets below:
                    </div>
                `;
                sec1DistrictList.appendChild(noticeCard);

                otherDistrictCrops.forEach(alm => {
                    const acard = document.createElement('div');
                    acard.className = 'mandi-item-card';
                    acard.style.borderLeftColor = 'var(--accent-blue)';
                    acard.innerHTML = `
                        <div class="mandi-item-header">
                            <div class="mandi-name-badge">
                                🏬 ${alm.market} Mandi
                            </div>
                            <div class="mandi-location-tag">
                                📍 ${alm.district}, ${alm.state} <span class="district-local-pill">📍 Same Selected District</span>
                            </div>
                        </div>
                        <div style="font-size: 0.95rem; color: #ffffff; display: flex; gap: 1.5rem; flex-wrap: wrap;">
                            <div>Trading Commodity: <strong style="color: #38bdf8;">${alm.commodity}</strong></div>
                            <div>Modal Price: <strong style="color: #6ee7b7;">₹${Number(alm.modal_price_quintal).toLocaleString('en-IN')}/qtn</strong></div>
                            <div>Date: <strong>${alm.arrival_date}</strong></div>
                        </div>
                    `;
                    sec1DistrictList.appendChild(acard);
                });
            } else {
                sec1DistrictList.innerHTML = `
                    <div class="mandi-item-card" style="border-left-color: #f59e0b;">
                        <div class="mandi-name-badge" style="color: #fef08a;">
                            ⚠️ No reporting Mandi markets found in ${district} today.
                        </div>
                    </div>
                `;
            }

            // SECTION 2: STATE MANDIS
            sec2StateSubtitle.textContent = `Other Mandis in ${state}`;
            sec2StateList.innerHTML = '';
            if (sMandis.length > 0) {
                sMandis.forEach(mandi => {
                    sec2StateList.appendChild(createMandiCard(mandi));
                });
            } else {
                sec2StateList.innerHTML = `
                    <div class="mandi-item-card" style="border-left-color: var(--card-border);">
                        <div style="color: var(--text-sub); font-size: 0.95rem;">
                            No other Mandis in ${state} reported ${crop} today.
                        </div>
                    </div>
                `;
            }

            // SECTION 3: BEST MANDI CHOICE
            if (best) {
                bestMarketName.textContent = `🏬 ${best.market} Mandi`;
                bestLocationTag.innerHTML = `📍 ${best.district}, ${best.state} ${best.distance_km === 0 ? '<span class="district-local-pill">📍 Same Selected District</span>' : `<span class="distance-pill">📏 ${best.distance_km} km away</span>`}`;
                bestReasonText.textContent = best.reason || `⭐ Recommended best price for ${crop}`;
                bestQuintalPrice.textContent = `₹${Number(best.modal_price_quintal || 0).toLocaleString('en-IN')}`;
                bestKgPrice.textContent = `₹${Number(best.modal_price_kg || 0).toLocaleString('en-IN')}`;
                bestCropName.textContent = best.commodity;
                bestMinPrice.textContent = `₹${Number(best.min_price_quintal || 0).toLocaleString('en-IN')}/qtn`;
                bestMaxPrice.textContent = `₹${Number(best.max_price_quintal || 0).toLocaleString('en-IN')}/qtn`;
                bestVariety.textContent = best.variety;
                bestDate.textContent = best.arrival_date;
            }

            // SECTION 4: REMAINING MANDIS (OTHER STATES / ALL INDIA)
            sec4RemainingList.innerHTML = '';
            if (rMandis.length > 0) {
                rMandis.forEach(mandi => {
                    sec4RemainingList.appendChild(createMandiCard(mandi));
                });
            } else {
                sec4RemainingList.innerHTML = `
                    <div class="mandi-item-card" style="border-left-color: var(--card-border);">
                        <div style="color: var(--text-sub); font-size: 0.95rem;">
                            No additional external Mandi records.
                        </div>
                    </div>
                `;
            }

            resultsContainer.classList.add('visible');
        }

        function createMandiCard(mandi) {
            const card = document.createElement('div');
            card.className = 'mandi-item-card';
            
            const modalQ = Number(mandi.modal_price_quintal || 0).toLocaleString('en-IN');
            const modalKg = Number(mandi.modal_price_kg || 0).toLocaleString('en-IN');
            const minQ = Number(mandi.min_price_quintal || 0).toLocaleString('en-IN');
            const maxQ = Number(mandi.max_price_quintal || 0).toLocaleString('en-IN');

            const distPill = mandi.distance_km === 0 || mandi.is_same_district
                ? '<span class="district-local-pill">📍 Same Selected District</span>' 
                : `<span class="distance-pill">📏 ${mandi.distance_km} km away</span>`;

            card.innerHTML = `
                <div class="mandi-item-header">
                    <div class="mandi-name-badge">
                        🏬 ${mandi.market} Mandi
                    </div>
                    <div class="mandi-location-tag">
                        📍 ${mandi.district}, ${mandi.state} ${distPill}
                    </div>
                </div>

                <div class="price-display-grid">
                    <div class="price-box">
                        <div class="price-label">Mandi Modal Price (Quintal)</div>
                        <div class="price-main">₹${modalQ}</div>
                        <div class="price-sub">per Quintal (100 kg)</div>
                    </div>
                    <div class="price-box">
                        <div class="price-label">Converted Price per Kg</div>
                        <div class="price-main">₹${modalKg}</div>
                        <div class="price-sub">per Kilogram</div>
                    </div>
                </div>

                <div class="meta-list">
                    <div class="meta-item">Crop: <strong>${mandi.commodity}</strong></div>
                    <div class="meta-item">Min Price: <strong>₹${minQ}/qtn</strong></div>
                    <div class="meta-item">Max Price: <strong>₹${maxQ}/qtn</strong></div>
                    <div class="meta-item">Variety: <strong>${mandi.variety}</strong></div>
                    <div class="meta-item">Date: <strong>${mandi.arrival_date}</strong></div>
                </div>
            `;
            return card;
        }

        function setLoading(isLoading) {
            if (isLoading) {
                btnSpinner.style.display = 'block';
                btnText.textContent = 'Fetching Mandi Data...';
                fetchBtn.disabled = true;
            } else {
                btnSpinner.style.display = 'none';
                btnText.textContent = 'Fetch Mandi Results';
                fetchBtn.disabled = false;
            }
        }

        function showAlert(msg) {
            alertBox.textContent = msg;
            alertBox.style.display = 'block';
        }

        function hideAlert() {
            alertBox.style.display = 'none';
        }
    </script>
</body>
</html>
"""

@app.route("/", methods=["GET"])
def index():
    """Render the main Mandi Price Intelligence web interface."""
    return render_template_string(HTML_TEMPLATE)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print("==================================================")
    print(f"India Mandi Price Checker Web App starting...")
    print(f"Serving at: http://127.0.0.1:{port}")
    print("==================================================")
    app.run(host="127.0.0.1", port=port, debug=True)
