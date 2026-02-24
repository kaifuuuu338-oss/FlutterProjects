/// App-wide constants
class AppConstants {
  // General
  static const String appName = 'AI ECD Screening';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String baseUrl = String.fromEnvironment(
    'ECD_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  // OTP / session endpoints (server-driven two-step flow)
  static const String otpInitiateEndpoint = '/auth/otp/initiate';
  static const String otpVerifyEndpoint = '/auth/otp/verify';
  static const String otpResendEndpoint = '/auth/otp/resend';
  static const String sessionExchangeEndpoint = '/auth/session';
  static const String screeningEndpoint = '/screening/submit';
  static const String childRegisterEndpoint = '/children/register';
  static const String childListEndpoint = '/children';
  static const String childDetailEndpoint = '/children';
  static const String referralEndpoint = '/referral/create';

  // Local Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String childrenDataKey = 'children_data';
  static const String screeningsDataKey = 'screenings_data';

  // Hive Box Names
  static const String awwBoxName = 'aww_box';
  static const String childBoxName = 'child_box';
  static const String screeningBoxName = 'screening_box';
  static const String referralBoxName = 'referral_box';
  static const String childSyncBoxName = 'child_sync_box';

  // Domain Constants
  static const List<String> domains = ['GM', 'FM', 'LC', 'COG', 'SE'];
  static const Map<String, String> domainNames = {
    'GM': 'Gross Motor',
    'FM': 'Fine Motor',
    'LC': 'Language & Communication',
    'COG': 'Cognitive',
    'SE': 'Social & Emotional',
  };

  // Andhra Pradesh district -> mandals (representative list for dropdown usage).
  static const Map<String, List<String>> apDistrictMandals = {
    'Anakapalli': ['Anakapalle', 'Achutapuram', 'Chodavaram', 'Kasimkota'],
    'Anantapur': ['Anantapur Urban', 'Raptadu', 'Atmakur', 'Bukkarayasamudram'],
    'Annamayya': ['Rajampet', 'Rayachoty', 'Kodur', 'Madanapalle'],
    'Bapatla': ['Bapatla', 'Chirala', 'Parchur', 'Karlapalem'],
    'Chittoor': ['Chittoor', 'Gudipala', 'Bangarupalem', 'Puttur'],
    'Dr. B.R. Ambedkar Konaseema': [
      'Amalapuram',
      'Mummidivaram',
      'Allavaram',
      'Razole',
    ],
    'East Godavari': [
      'Rajamahendravaram Rural',
      'Kadiam',
      'Seethanagaram',
      'Rajanagaram',
    ],
    'Eluru': ['Eluru', 'Pedapadu', 'Denduluru', 'Unguturu'],
    'Guntur': ['Guntur', 'Mangalagiri', 'Tadikonda', 'Pedakakani'],
    'Kakinada': ['Kakinada Rural', 'Samalkota', 'Pithapuram', 'Jaggampeta'],
    'Krishna': ['Machilipatnam', 'Pedana', 'Guduru', 'Movva'],
    'Kurnool': ['Kurnool', 'Orvakal', 'Kodumur', 'Adoni'],
    'Nandyal': ['Nandyal', 'Atmakur', 'Allagadda', 'Banaganapalle'],
    'NTR': ['Vijayawada Urban', 'Ibrahimpatnam', 'Gannavaram', 'Kankipadu'],
    'Palnadu': ['Narasaraopet', 'Sattenapalle', 'Vinukonda', 'Macherla'],
    'Parvathipuram Manyam': [
      'Parvathipuram',
      'Palakonda',
      'Seethampeta',
      'Kurupam',
    ],
    'Prakasam': ['Ongole', 'Kandukur', 'Markapur', 'Addanki'],
    'SPSR Nellore': ['Nellore', 'Kovur', 'Kavali', 'Atmakur'],
    'Sri Sathya Sai': ['Puttaparthi', 'Dharmavaram', 'Kadiri', 'Hindupur'],
    'Srikakulam': ['Srikakulam', 'Amadalavalasa', 'Tekkali', 'Ichchapuram'],
    'Tirupati': ['Tirupati Urban', 'Srikalahasti', 'Renigunta', 'Puttur'],
    'Visakhapatnam': [
      'Visakhapatnam Urban',
      'Bheemunipatnam',
      'Anandapuram',
      'Pendurthi',
    ],
    'Vizianagaram': [
      'Vizianagaram',
      'Gajapathinagaram',
      'Bobbili',
      'Cheepurupalle',
    ],
    'West Godavari': [
      'Bhimavaram',
      'Narasapuram',
      'Palacole',
      'Tadepalligudem',
    ],
    'YSR Kadapa': ['Kadapa', 'Proddatur', 'Jammalamadugu', 'Pulivendula'],
  };

  // Age Groups
  static const Map<String, String> ageGroups = {
    '0-6m': '0-6 Months',
    '6-12m': '6-12 Months',
    '12-18m': '12-18 Months',
    '18-24m': '18-24 Months',
    '24-36m': '24-36 Months',
    '36-48m': '36-48 Months',
    '48-60m': '48-60 Months',
    '60-72m': '60-72 Months',
  };

  // Risk Levels
  static const Map<String, String> riskLevels = {
    'low': 'Low Risk',
    'medium': 'Medium Risk',
    'high': 'High Risk',
    'critical': 'Critical Risk',
  };

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration sessionTimeout = Duration(hours: 1);

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const String phoneRegex = r'^[0-9]{10}$';

  // DPDP Act Compliance
  static const String dataUsageDisclaimer = '''
This app uses child development data for screening purposes only.
Your data will be securely stored and used only for:
- Early identification of developmental risks
- Providing personalized intervention recommendations
- Government health program monitoring

This is NOT diagnosis. All results are for decision-support only.
Data will be protected under the Digital Personal Data Protection Act, 2023.
  ''';
}
