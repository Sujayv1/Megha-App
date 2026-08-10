import os
import json
import time
import urllib.request
import urllib.parse
# pyrefly: ignore [missing-import]
from flask import Flask, jsonify, request, render_template_string

app = Flask(__name__)

# OGD India Mandi Price API Configuration
API_KEY = "579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b"
RESOURCE_ID = "9ef84268-d588-465a-a308-a864a43d0070"
BASE_URL = f"https://api.data.gov.in/resource/{RESOURCE_ID}"

# Simple In-Memory Cache to prevent HTTP 429 Rate Limits from data.gov.in
API_CACHE = {}
CACHE_TTL = 300  # 5 minutes cache

def fetch_data_gov_records(params):
    """Helper function to execute HTTP request to data.gov.in Mandi API with caching."""
    query_str = urllib.parse.urlencode(sorted(params.items()))
    cache_key = query_str
    now = time.time()

    # Return cached data if valid
    if cache_key in API_CACHE:
        cached_time, cached_records = API_CACHE[cache_key]
        if now - cached_time < CACHE_TTL:
            return cached_records

    try:
        url = f"{BASE_URL}?api-key={API_KEY}&format=json&{query_str}"
        req = urllib.request.Request(
            url, 
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MandiPriceApp/1.0"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
            records = data.get("records", [])
            API_CACHE[cache_key] = (now, records)
            return records
    except Exception as e:
        print(f"[Mandi API Error] {e}")
        if cache_key in API_CACHE:
            return API_CACHE[cache_key][1]
        return []

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
    "Uttar Pradesh": ["Agra", "Aligarh", "Ambedkar Nagar", "Amethi", "Amroha", "Auraiya", "Ayodhya", "Azamgarh", "Badaun", "Baghpat", "Bahraich", "Ballia", "Balrampur", "Banda", "Barabanki", "Bareilly", "Basti", "Bhajnoi", "Bijnor", "Bulandshahr", "Chandauli", "Chitrakoot", "Deoria", "Etah", "Etawah", "Farrukhabad", "Fatehpur", "Firozabad", "Gautam Buddha Nagar", "Ghaziabad", "Ghazipur", "Gonda", "Gorakhpur", "Hamirpur", "Hapur", "Hardoi", "Hathras", "Jalaun", "Jaunpur", "Jhansi", "Kannauj", "Kanpur Dehat", "Kanpur Nagar", "Kasganj", "Kaushambi", "Kheri", "Kushinagar", "Lalitpur", "Lucknow", "Maharajganj", "Mahoba", "Mainpuri", "Mathura", "Mau", "Meerut", "Mirzapur", "Moradabad", "Muzaffarnagar", "Pilibhit", "Pratapgarh", "Prayagraj", "Raebareli", "Rampur", "Saharanpur", "Sambhal", "Sant Kabir Nagar", "Shahjahanpur", "Shamli", "Shravasti", "Siddharthnagar", "Sitapur", "Sonbhadra", "Sultanpur", "Unnao", "Varanasi"],
    "Uttarakhand": ["Almora", "Bageshwar", "Chamoli", "Champawat", "Dehradun", "Haridwar", "Nainital", "Pauri Garhwal", "Pithoragarh", "Rudraprayag", "Tehri Garhwal", "Udham Singh Nagar", "Uttarkashi"],
    "West Bengal": ["Alipurduar", "Bankura", "Birbhum", "Cooch Behar", "Dakshin Dinajpur", "Darjeeling", "Hooghly", "Howrah", "Jalpaiguri", "Jhargram", "Kalimpong", "Kolkata", "Malda", "Murshidabad", "Nadia", "North 24 Parganas", "Paschim Bardhaman", "Paschim Medinipur", "Purba Bardhaman", "Purba Medinipur", "Purulia", "South 24 Parganas", "Uttar Dinajpur"]
}

POPULAR_COMMODITIES = [
    "Apple", "Arhar (Tur/Red Gram)", "Ashgourd", "Bajra(Pearl Millet/Cumbu)", "Banana", "Banana - Green", 
    "Barley (Jau)", "Bengal Gram(Gram)(Whole)", "Bitter gourd", "Bhindi(Ladies Finger)", "Black Gram (Urd Beans)", 
    "Bottle gourd", "Brinjal", "Cabbage", "Capsicum", "Carrot", "Cauliflower", "Chili Red", "Chilli Green", 
    "Coconut", "Coriander(Leaves)", "Cotton", "Cucumber", "Cumin Seed(Jeera)", "Drumstick", "Fish", "Garlic", 
    "Ginger(Green)", "Grapes", "Green Gram (Moong)", "Groundnut", "Guava", "Jowar(Sorghum)", "Lemon", 
    "Maize", "Mango", "Mustard", "Onion", "Papaya", "Papaya(Raw)", "Peas(Dry)", "Peas wet", "Pomegranate", 
    "Potato", "Pumpkin", "Radish", "Ragi (Finger Millet)", "Rice", "Soyabean", "Spinach", "Sugarcane", 
    "Sweet Potato", "Tomato", "Turmeric", "Watermelon", "Wheat"
]

def match_commodity_records(records, search_crop):
    """Case-insensitive fuzzy matching for crop names."""
    if not records or not search_crop:
        return []
    crop_term = search_crop.strip().lower()
    matched = []
    for r in records:
        cm = r.get("commodity", "").strip().lower()
        if not cm:
            continue
        if crop_term == cm or crop_term in cm or cm in crop_term:
            matched.append(r)
    return matched

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
    """Fast local autocomplete from pre-loaded commodities list (zero API rate-limit overhead)."""
    q = request.args.get("q", "").strip().lower()
    if not q:
        return jsonify({"status": "success", "commodities": POPULAR_COMMODITIES[:25]})
    
    matched = [c for c in POPULAR_COMMODITIES if q in c.lower()]
    return jsonify({"status": "success", "commodities": matched[:30]})

@app.route("/api/fetch-prices", methods=["GET"])
def fetch_prices():
    """
    Core API route with 4-stage resilient matching:
    1. District Mandis matching crop
    2. State Mandis matching crop (if district has no entry)
    3. All-India Mandis matching crop (if state has no entry)
    4. Active Mandis in District/State (if crop has no entry anywhere)
    Returns exact Mandi market prices - NO ZERO / NO AVERAGING!
    """
    state = request.args.get("state", "").strip()
    district = request.args.get("district", "").strip()
    commodity = request.args.get("commodity", "").strip()

    if not state or not district or not commodity:
        return jsonify({
            "status": "error",
            "message": "State, District, and Crop selection are required."
        }), 400

    crop_lower = commodity.strip().lower()

    # 1. Fetch District Level Records
    district_raw = fetch_data_gov_records({
        "limit": 500,
        "filters[state]": state,
        "filters[district]": district
    })
    local_matched_records = match_commodity_records(district_raw, commodity)
    scope_note = f"{district}, {state}"

    # 2. Fallback to State level records if district has no record for this crop
    if not local_matched_records:
        state_raw = fetch_data_gov_records({
            "limit": 500,
            "filters[state]": state
        })
        local_matched_records = match_commodity_records(state_raw, commodity)
        if local_matched_records:
            scope_note = f"{state} Mandis (Nearest to {district})"

    # 3. Fallback to All-India records for commodity if state has no record today
    if not local_matched_records:
        all_india_raw = fetch_data_gov_records({
            "limit": 500,
            "filters[commodity]": commodity
        })
        local_matched_records = match_commodity_records(all_india_raw, commodity)
        if local_matched_records:
            scope_note = f"Mandis Reporting Prices for {commodity} (Nearest available to {district}, {state})"

    # 4. Fallback to any active Mandis in user's district or state if crop is unique
    if not local_matched_records:
        if district_raw:
            local_matched_records = district_raw
            scope_note = f"Active Mandis in {district}, {state}"
        elif 'state_raw' in locals() and state_raw:
            local_matched_records = state_raw
            scope_note = f"Active Mandis in {state}"
        else:
            bulk_recs = fetch_data_gov_records({"limit": 200})
            local_matched_records = bulk_recs[:10]
            scope_note = f"Active Indian Mandis"

    # Process Local Mandi Prices (No Averaging - exact non-zero prices per mandi!)
    local_mandis = []
    if local_matched_records:
        seen_markets = set()
        for r in local_matched_records:
            market_name = r.get("market", "Local Mandi")
            if market_name in seen_markets:
                continue

            try:
                modal_p = float(r.get("modal_price", 0))
                min_p = float(r.get("min_price", modal_p))
                max_p = float(r.get("max_price", modal_p))
            except (ValueError, TypeError):
                continue

            # Fallback if modal_p is 0, use min/max or default valid mandi value
            if modal_p <= 0 and max_p > 0:
                modal_p = max_p
            if modal_p <= 0 and min_p > 0:
                modal_p = min_p

            if modal_p > 0:
                seen_markets.add(market_name)
                local_mandis.append({
                    "market": market_name,
                    "district": r.get("district", district),
                    "state": r.get("state", state),
                    "commodity": r.get("commodity", commodity),
                    "variety": r.get("variety", "Standard"),
                    "grade": r.get("grade", "Grade A"),
                    "modal_price_quintal": round(modal_p, 2),
                    "modal_price_kg": round(modal_p / 100.0, 2),
                    "min_price_quintal": round(min_p if min_p > 0 else modal_p, 2),
                    "max_price_quintal": round(max_p if max_p > 0 else modal_p, 2),
                    "arrival_date": r.get("arrival_date", "Latest")
                })

    # Fetch All-India Records for National Highest Price
    all_india_raw = fetch_data_gov_records({
        "limit": 500,
        "filters[commodity]": commodity
    })
    all_india_matched = match_commodity_records(all_india_raw, commodity)
    
    if not all_india_matched:
        bulk_recs = fetch_data_gov_records({"limit": 1000})
        all_india_matched = match_commodity_records(bulk_recs, commodity)
        if not all_india_matched and local_matched_records:
            all_india_matched = local_matched_records

    highest_data = None
    if all_india_matched:
        valid_recs = []
        for r in all_india_matched:
            try:
                max_p = float(r.get("max_price", 0)) or float(r.get("modal_price", 0))
                if max_p > 0:
                    valid_recs.append((max_p, r))
            except (ValueError, TypeError):
                continue

        if valid_recs:
            top_price, top_rec = max(valid_recs, key=lambda x: x[0])
            modal_p = float(top_rec.get("modal_price", top_price))

            highest_data = {
                "max_price_quintal": round(top_price, 2),
                "max_price_kg": round(top_price / 100.0, 2),
                "modal_price_quintal": round(modal_p, 2),
                "market": top_rec.get("market", "Unknown Market"),
                "district": top_rec.get("district", "Unknown District"),
                "state": top_rec.get("state", "Unknown State"),
                "arrival_date": top_rec.get("arrival_date", "Latest"),
                "variety": top_rec.get("variety", "Standard")
            }

    # Comparison metrics against local top mandi price
    diff_percent = None
    diff_amount_quintal = None
    if local_mandis and highest_data:
        first_local_modal = local_mandis[0]["modal_price_quintal"]
        if first_local_modal > 0:
            diff_amount_quintal = round(highest_data["max_price_quintal"] - first_local_modal, 2)
            if diff_amount_quintal > 0:
                diff_percent = round((diff_amount_quintal / first_local_modal) * 100, 1)

    return jsonify({
        "status": "success",
        "query": {
            "state": state,
            "district": district,
            "commodity": commodity
        },
        "local_mandis": local_mandis,
        "scope_note": scope_note,
        "highest": highest_data,
        "comparison": {
            "diff_amount_quintal": diff_amount_quintal,
            "diff_percent": diff_percent
        }
    })

# Embedded Modern HTML/CSS/JS Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>India Mandi Price Checker | Real-Time Agricultural Commodity Prices</title>
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
            gap: 1.5rem;
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
            margin-bottom: 0.5rem;
            flex-wrap: wrap;
            gap: 0.5rem;
        }

        .section-title {
            font-family: var(--font-heading);
            font-size: 1.3rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .section-subtitle {
            font-size: 0.88rem;
            color: var(--accent-green-bright);
            background: rgba(52, 211, 153, 0.1);
            padding: 0.3rem 0.75rem;
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
        .highest-card .price-main { color: #fde047; }

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

        /* Highest Card */
        .highest-card {
            background: var(--card-bg);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--card-border);
            border-left: 5px solid var(--accent-gold);
            background: linear-gradient(135deg, rgba(251, 191, 36, 0.06) 0%, rgba(255, 255, 255, 0.03) 100%);
            border-radius: var(--radius-lg);
            padding: 1.75rem;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.3);
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
        }

        .highest-tag {
            font-size: 0.8rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--accent-gold);
        }

        .diff-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            background: rgba(245, 158, 11, 0.18);
            border: 1px solid rgba(245, 158, 11, 0.4);
            color: #fef08a;
            padding: 0.4rem 0.9rem;
            border-radius: 999px;
            font-size: 0.85rem;
            font-weight: 700;
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

        /* Empty State / Errors */
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
                Live Mandi Prices • India
            </div>
            <h1>Harvested Crop Price Intelligence</h1>
            <p class="subtitle">Select your State, District, and harvested crop to check the exact price in your local Mandi and discover the highest market price across India.</p>
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

                <!-- Crop Input with Autocomplete -->
                <div class="input-group">
                    <label for="cropInput">Harvested Crop <span>*</span></label>
                    <input type="text" id="cropInput" list="cropDatalist" placeholder="e.g. Wheat, Potato, Tomato..." autocomplete="off">
                    <datalist id="cropDatalist"></datalist>
                </div>
            </div>

            <button class="btn-fetch" id="fetchBtn">
                <div class="spinner" id="btnSpinner"></div>
                <span id="btnText">Fetch Mandi Prices</span>
            </button>
        </div>

        <div class="alert-box" id="alertBox"></div>

        <!-- Results Display Container -->
        <div class="results-container" id="resultsContainer">
            
            <!-- Section 1: Local Mandi Prices -->
            <div class="section-group">
                <div class="section-header">
                    <div class="section-title">
                        📍 Your Local Mandi Prices
                    </div>
                    <div class="section-subtitle" id="localScopeSubtitle">District, State</div>
                </div>

                <!-- Container where each Mandi market item is rendered directly -->
                <div class="mandi-card-list" id="localMandiList"></div>
            </div>

            <!-- Section 2: All-India Highest Mandi Price -->
            <div class="section-group">
                <div class="section-header" style="margin-top: 1rem;">
                    <div class="section-title" style="color: var(--accent-gold);">
                        🏆 All-India Highest Mandi Price
                    </div>
                </div>

                <div class="highest-card">
                    <div class="mandi-item-header">
                        <div style="display: flex; flex-direction: column; gap: 0.2rem;">
                            <div class="highest-tag">Highest Mandi Record in India</div>
                            <div class="mandi-name-badge" id="highestMarketTitle">Market Name</div>
                            <div style="color: var(--text-sub); font-size: 0.9rem;" id="highestLocationSub">District, State</div>
                        </div>
                        <div class="diff-pill" id="diffPill">
                            ⚡ +0% Higher
                        </div>
                    </div>

                    <div class="price-display-grid">
                        <div class="price-box">
                            <div class="price-label">Highest Mandi Price (Quintal)</div>
                            <div class="price-main" id="highestQuintalPrice">₹0</div>
                            <div class="price-sub">per Quintal (100 kg)</div>
                        </div>
                        <div class="price-box">
                            <div class="price-label">Converted Price per Kg</div>
                            <div class="price-main" id="highestKgPrice">₹0</div>
                            <div class="price-sub">per Kilogram</div>
                        </div>
                    </div>

                    <div class="meta-list">
                        <div class="meta-item">Variety: <strong id="highestVariety">Standard</strong></div>
                        <div class="meta-item">Modal Price: <strong id="highestModalPrice">₹0/qtn</strong></div>
                        <div class="meta-item">Market: <strong id="highestMarketName">-</strong></div>
                        <div class="meta-item">Date: <strong id="highestDate">-</strong></div>
                    </div>
                </div>
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
        const cropInput = document.getElementById('cropInput');
        const cropDatalist = document.getElementById('cropDatalist');
        const fetchBtn = document.getElementById('fetchBtn');
        const btnSpinner = document.getElementById('btnSpinner');
        const btnText = document.getElementById('btnText');
        const alertBox = document.getElementById('alertBox');
        const resultsContainer = document.getElementById('resultsContainer');

        const localScopeSubtitle = document.getElementById('localScopeSubtitle');
        const localMandiList = document.getElementById('localMandiList');

        const highestMarketTitle = document.getElementById('highestMarketTitle');
        const highestLocationSub = document.getElementById('highestLocationSub');
        const highestQuintalPrice = document.getElementById('highestQuintalPrice');
        const highestKgPrice = document.getElementById('highestKgPrice');
        const highestVariety = document.getElementById('highestVariety');
        const highestModalPrice = document.getElementById('highestModalPrice');
        const highestMarketName = document.getElementById('highestMarketName');
        const highestDate = document.getElementById('highestDate');
        const diffPill = document.getElementById('diffPill');

        // Initial Setup
        document.addEventListener('DOMContentLoaded', () => {
            loadStates();
            loadCommodities('');
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

        // Crop Autocomplete Input Listener
        cropInput.addEventListener('input', (e) => {
            loadCommodities(e.target.value);
        });

        async function loadCommodities(query) {
            try {
                const res = await fetch(`/api/commodities?q=${encodeURIComponent(query)}`);
                const data = await res.json();
                if (data.status === 'success') {
                    cropDatalist.innerHTML = '';
                    data.commodities.forEach(cm => {
                        const opt = document.createElement('option');
                        opt.value = cm;
                        cropDatalist.appendChild(opt);
                    });
                }
            } catch (err) {
                console.error(err);
            }
        }

        // Handle Fetch Button Click
        fetchBtn.addEventListener('click', async () => {
            const state = stateSelect.value;
            const district = districtSelect.value;
            const crop = cropInput.value.trim();

            if (!state || !district || !crop) {
                showAlert('Please select State, District, and enter your Harvested Crop.');
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

                if ((!data.local_mandis || data.local_mandis.length === 0) && !data.highest) {
                    showAlert(`No Mandi price records found for "${crop}".`);
                    setLoading(false);
                    return;
                }

                renderResults(data, crop, district, state);
            } catch (err) {
                showAlert('Network error while querying Mandi price API. Please try again.');
            } finally {
                setLoading(false);
            }
        });

        function renderResults(data, crop, district, state) {
            const mandis = data.local_mandis || [];
            const highest = data.highest;
            const comp = data.comparison;

            localScopeSubtitle.textContent = data.scope_note || `${district}, ${state}`;
            localMandiList.innerHTML = '';

            // Render Local Place Mandis (NO ZERO! NO AVERAGING!)
            if (mandis.length > 0) {
                mandis.forEach(mandi => {
                    const card = document.createElement('div');
                    card.className = 'mandi-item-card';
                    
                    const modalQ = Number(mandi.modal_price_quintal || 0).toLocaleString('en-IN');
                    const modalKg = Number(mandi.modal_price_kg || 0).toLocaleString('en-IN');
                    const minQ = Number(mandi.min_price_quintal || 0).toLocaleString('en-IN');
                    const maxQ = Number(mandi.max_price_quintal || 0).toLocaleString('en-IN');

                    card.innerHTML = `
                        <div class="mandi-item-header">
                            <div class="mandi-name-badge">
                                🏬 ${mandi.market} Mandi
                            </div>
                            <div class="mandi-location-tag">
                                📍 ${mandi.district}, ${mandi.state}
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
                    localMandiList.appendChild(card);
                });
            } else {
                localMandiList.innerHTML = `
                    <div class="mandi-item-card" style="border-left-color: #f59e0b;">
                        <div class="mandi-name-badge" style="color: #fef08a;">
                            ⚠️ No active Mandi price record found for "${crop}" in ${district}, ${state} today.
                        </div>
                    </div>
                `;
            }

            // Render All-India Highest Card
            if (highest) {
                highestMarketTitle.textContent = `${highest.market} Mandi`;
                highestLocationSub.textContent = `📍 ${highest.district}, ${highest.state}`;
                highestQuintalPrice.textContent = `₹${Number(highest.max_price_quintal || 0).toLocaleString('en-IN')}`;
                highestKgPrice.textContent = `₹${Number(highest.max_price_kg || 0).toLocaleString('en-IN')}`;
                highestModalPrice.textContent = `₹${Number(highest.modal_price_quintal || 0).toLocaleString('en-IN')}/qtn`;
                highestVariety.textContent = highest.variety;
                highestMarketName.textContent = `${highest.market} (${highest.state})`;
                highestDate.textContent = highest.arrival_date;

                if (comp && comp.diff_percent !== null && comp.diff_percent > 0) {
                    diffPill.style.display = 'inline-flex';
                    diffPill.innerHTML = `⚡ +${comp.diff_percent}% (₹${comp.diff_amount_quintal}/qtn) Higher than local price`;
                } else {
                    diffPill.style.display = 'none';
                }
            }

            resultsContainer.classList.add('visible');
        }

        function setLoading(isLoading) {
            if (isLoading) {
                btnSpinner.style.display = 'block';
                btnText.textContent = 'Fetching Mandi Data...';
                fetchBtn.disabled = true;
            } else {
                btnSpinner.style.display = 'none';
                btnText.textContent = 'Fetch Mandi Prices';
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
