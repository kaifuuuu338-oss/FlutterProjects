class QuestionBank {
  static Map<String, List<String>> byAgeMonths(
    int ageMonths, {
    String languageCode = 'en',
  }) {
    final Map<String, Map<String, List<String>>> bank =
        _banks[languageCode] ?? _banks['en']!;
    if (ageMonths <= 12) return bank['0-12']!;
    final years = ageMonths ~/ 12;
    if (years <= 2) return bank['13-24']!; // 13-35 months (1-2 years)
    if (years == 3) return bank['25-36']!; // 36-47 months
    if (years == 4) return bank['37-48']!; // 48-59 months (4 years)
    if (years == 5) return bank['49-60']!; // 60-71 months (5 years)
    return bank['61-72']!; // 72+ months (6 years)
  }

  static const Map<String, Map<String, Map<String, List<String>>>> _banks = {
    'en': _bankEn,
    'te': _bankTe,
    'hi': _bankHi,
  };

  // English questions
  static const Map<String, Map<String, List<String>>> _bankEn = {
    '0-12': _q0To12En,
    '13-24': _q12To24En,
    '25-36': _q24To36En,
    '37-48': _q36To48En,
    '49-60': _q48To60En,
    '61-72': _q60To72En,
  };

  // Telugu questions
  static const Map<String, Map<String, List<String>>> _bankTe = {
    '0-12': _q0To12Te,
    '13-24': _q12To24Te,
    '25-36': _q24To36Te,
    '37-48': _q36To48Te,
    '49-60': _q48To60Te,
    '61-72': _q60To72Te,
  };

  // Hindi questions
  static const Map<String, Map<String, List<String>>> _bankHi = {
    '0-12': _q0To12Hi,
    '13-24': _q12To24Hi,
    '25-36': _q24To36Hi,
    '37-48': _q36To48Hi,
    '49-60': _q48To60Hi,
    '61-72': _q60To72Hi,
  };

  // 0-12 months (English)
  static const Map<String, List<String>> _q0To12En = {
    'GM': [
      'Does the baby move both arms and legs equally?',
      'Can the baby lift their head while lying on the stomach (tummy time)?',
      'Does the baby hold their head steady without support?',
      'Can the baby roll over (tummy to back or back to tummy)?',
      'Can the baby sit with support?',
    ],
    'FM': [
      'Does the baby grasp your finger when placed in their hand?',
      'Does the baby bring hands to the mouth?',
      'Can the baby reach for a toy placed in front of them?',
      'Can the baby transfer a toy from one hand to the other?',
      'Does the baby use the whole hand to hold objects (palmar grasp)?',
    ],
    'LC': [
      'Does the baby respond to sounds or loud noises?',
      'Does the baby turn toward a familiar voice?',
      'Does the baby make cooing or babbling sounds?',
      'Does the baby laugh or squeal?',
      'Does the baby respond when their name is called?',
    ],
    'COG': [
      'Does the baby follow a moving object with their eyes?',
      'Does the baby look for a toy when it is partially hidden?',
      'Does the baby explore objects by shaking, banging, or mouthing them?',
      'Does the baby show curiosity about new objects?',
      'Does the baby recognize familiar people?',
    ],
    'SE': [
      'Does the baby smile in response to others (social smile)?',
      'Does the baby make eye contact during interaction?',
      'Does the baby enjoy playing with caregivers?',
      'Does the baby show stranger anxiety (around 6-9 months)?',
      'Does the baby express different emotions (happy, upset, excited)?',
    ],
  };

  // 13-24 months (English)
  static const Map<String, List<String>> _q12To24En = {
    'GM': [
      'Can the child walk independently without support?',
      'Can the child run without frequently falling?',
      'Can the child kick a ball forward?',
      'Can the child walk up a few stairs with support?',
      'Can the child stand on tiptoes?',
    ],
    'FM': [
      'Can the child stack 4 or more blocks?',
      'Can the child turn pages of a book (one at a time)?',
      'Can the child scribble spontaneously with a crayon?',
      'Can the child use a spoon with minimal spilling?',
      'Can the child remove simple clothing (like socks)?',
    ],
    'LC': [
      'Does the child use at least 20-50 meaningful words?',
      'Does the child combine two words (e.g., "more milk")?',
      'Can the child follow simple two-step instructions?',
      'Does the child point to familiar objects when named?',
      'Does the child name familiar people or objects?',
    ],
    'COG': [
      'Can the child match similar objects (e.g., two same toys)?',
      'Does the child pretend play (e.g., feeding a doll)?',
      'Can the child identify body parts when asked?',
      'Can the child solve simple problems (like moving an object to reach a toy)?',
      'Does the child understand simple concepts like "big" and "small"?',
    ],
    'SE': [
      'Does the child show affection to familiar people?',
      'Does the child imitate adult actions (e.g., sweeping, talking on phone)?',
      'Does the child play alongside other children (parallel play)?',
      'Does the child show frustration when unable to do something?',
      'Does the child seek comfort from caregivers when upset?',
    ],
  };

  // 25-36 months (English)
  static const Map<String, List<String>> _q24To36En = {
    'GM': [
      'Can the child run smoothly without falling frequently?',
      'Can the child climb well (e.g., onto furniture or playground equipment)?',
      'Can the child pedal a tricycle?',
      'Can the child walk up and down stairs using alternate feet?',
      'Can the child jump forward with both feet together?',
    ],
    'FM': [
      'Can the child copy a simple circle?',
      'Can the child build a tower of 6-8 blocks?',
      'Can the child turn door handles or unscrew lids?',
      'Can the child use a spoon and fork properly?',
      'Can the child put on simple clothing (like a T-shirt)?',
    ],
    'LC': [
      'Does the child speak in 3-4 word sentences?',
      'Can the child tell their name and age?',
      'Is the child\'s speech understandable to familiar adults most of the time?',
      'Can the child follow three-step instructions?',
      'Can the child answer simple "what" or "where" questions?',
    ],
    'COG': [
      'Can the child sort objects by color or shape?',
      'Can the child complete simple puzzles (3-4 pieces)?',
      'Does the child understand the concept of counting (e.g., counts 1-3)?',
      'Can the child remember parts of a story?',
      'Does the child understand basic time concepts like "now" and "later"?',
    ],
    'SE': [
      'Does the child play cooperatively with other children?',
      'Can the child take turns during play?',
      'Does the child show a wide range of emotions?',
      'Can the child separate from parents without extreme distress?',
      'Does the child show concern when another child is upset?',
    ],
  };

  // 37-48 months (English)
  static const Map<String, List<String>> _q36To48En = {
    'GM': [
      'Can the child hop on one foot for a few seconds?',
      'Can the child catch a bounced ball most of the time?',
      'Can the child climb stairs without support using alternating feet?',
      'Can the child skip or attempt to skip?',
      'Can the child stand on one foot for at least 5 seconds?',
    ],
    'FM': [
      'Can the child copy a square shape?',
      'Can the child draw a person with at least 3 body parts?',
      'Can the child cut paper with child-safe scissors?',
      'Can the child button and unbutton clothes?',
      'Can the child hold a pencil with a proper grip?',
    ],
    'LC': [
      'Does the child speak in full sentences (5-6 words)?',
      'Can the child tell a short story about an event?',
      'Is the child\'s speech understandable to strangers?',
      'Can the child answer "why" questions?',
      'Can the child follow complex instructions (3-4 steps)?',
    ],
    'COG': [
      'Can the child name at least four colors correctly?',
      'Can the child count at least 5 objects accurately?',
      'Does the child understand the concept of "same" and "different"?',
      'Can the child complete a simple 6-8 piece puzzle?',
      'Can the child understand basic sequencing (first, next, last)?',
    ],
    'SE': [
      'Does the child prefer playing with other children rather than alone?',
      'Can the child follow simple rules during games?',
      'Does the child show empathy toward others?',
      'Can the child control emotions better than at age 3?',
      'Does the child show independence in daily activities (toileting, dressing)?',
    ],
  };

  // 49-60 months (English)
  static const Map<String, List<String>> _q48To60En = {
    'GM': [
      'Can the child skip smoothly?',
      'Can the child balance on one foot for at least 10 seconds?',
      'Can the child hop forward multiple times on one foot?',
      'Can the child catch a small ball with both hands?',
      'Can the child participate in simple group physical games (e.g., running, chasing)?',
    ],
    'FM': [
      'Can the child copy a triangle shape?',
      'Can the child draw a person with at least 6 body parts?',
      'Can the child write some letters or numbers?',
      'Can the child color within the lines mostly?',
      'Can the child tie a simple knot (or attempt to tie shoelaces)?',
    ],
    'LC': [
      'Does the child speak clearly in full, grammatically correct sentences?',
      'Can the child describe a recent event in detail?',
      'Can the child understand and use future tense (e.g., "I will go")?',
      'Can the child follow multi-step instructions (4-5 steps)?',
      'Can the child answer questions about a story after listening to it?',
    ],
    'COG': [
      'Can the child count at least 10 objects correctly?',
      'Can the child recognize some letters or numbers?',
      'Does the child understand basic concepts of time (yesterday, today, tomorrow)?',
      'Can the child solve simple reasoning problems?',
      'Can the child identify similarities between two objects (e.g., apple and banana are fruits)?',
    ],
    'SE': [
      'Does the child cooperate and share with other children?',
      'Can the child follow rules in structured games?',
      'Does the child express feelings using words rather than only actions?',
      'Can the child handle minor disappointments without extreme tantrums?',
      'Does the child show responsibility for small tasks (e.g., cleaning up toys)?',
    ],
  };

  // 61-72 months (English)
  static const Map<String, List<String>> _q60To72En = {
    'GM': [
      'Can the child skip with coordination and rhythm?',
      'Can the child ride a bicycle with or without training wheels?',
      'Can the child jump rope or attempt coordinated jumping activities?',
      'Can the child throw and catch a small ball accurately?',
      'Can the child participate in team physical activities (e.g., simple sports)?',
    ],
    'FM': [
      'Can the child write their full name clearly?',
      'Can the child draw recognizable pictures with multiple details?',
      'Can the child cut along a straight or curved line accurately?',
      'Can the child use proper pencil grip consistently?',
      'Can the child complete basic crafts (folding paper, gluing shapes neatly)?',
    ],
    'LC': [
      'Can the child speak fluently with clear pronunciation?',
      'Can the child read simple words or short sentences?',
      'Can the child understand and answer "how" and "why" questions clearly?',
      'Can the child retell a short story in sequence?',
      'Can the child follow classroom instructions independently?',
    ],
    'COG': [
      'Can the child count up to 20 correctly?',
      'Can the child perform simple addition or subtraction (e.g., 2 + 1)?',
      'Can the child identify days of the week?',
      'Can the child understand simple cause-and-effect relationships?',
      'Can the child categorize objects into groups (e.g., animals, vehicles)?',
    ],
    'SE': [
      'Does the child make and maintain friendships?',
      'Can the child resolve small conflicts with minimal adult help?',
      'Does the child follow school rules consistently?',
      'Can the child express feelings appropriately in different situations?',
      'Does the child show confidence in completing tasks independently?',
    ],
  };

  // Telugu placeholders (filled in follow-up patches)
  static const Map<String, List<String>> _q0To12Te = {
    'GM': [
      'శిశువు రెండు చేతులు, రెండు కాళ్లను సమానంగా కదుపుతుందా?',
      'శిశువు పొట్టపై పడుకున్నప్పుడు (టమ్మీ టైమ్) తల ఎత్తగలదా?',
      'శిశువు సహాయం లేకుండా తలను స్థిరంగా ఉంచగలదా?',
      'శిశువు పొట్ట నుండి వెనక్కి లేదా వెన్ను నుండి పొట్టకు తిప్పుకోగలదా?',
      'శిశువు సహాయంతో కూర్చోగలదా?',
    ],
    'FM': [
      'చేతిలో పెట్టినప్పుడు శిశువు మీ వేలిని పట్టుకుంటుందా?',
      'శిశువు చేతులను నోటికి తీసుకెళుతుందా?',
      'ముందు ఉంచిన బొమ్మను చేరుకోగలదా?',
      'బొమ్మను ఒక చేతి నుంచి మరొక చేతికి మార్చగలదా?',
      'శిశువు మొత్తం చేతితో వస్తువులను పట్టుకుంటుందా (పాల్మర్ గ్రాస్ప్)?',
    ],
    'LC': [
      'శిశువు శబ్దాలకు లేదా పెద్ద శబ్దాలకు స్పందిస్తుందా?',
      'శిశువు పరిచయమైన గొంతు వైపు తిరుగుతుందా?',
      'శిశువు కూయింగ్ లేదా బాబ్లింగ్ శబ్దాలు చేస్తుందా?',
      'శిశువు నవ్వుతుందా లేదా కిక్కిరిస్తుంది?',
      'శిశువు పేరు పిలిస్తే స్పందిస్తుందా?',
    ],
    'COG': [
      'శిశువు కదులుతున్న వస్తువును కళ్లతో అనుసరిస్తుందా?',
      'బొమ్మ భాగంగా దాచినప్పుడు శిశువు దాన్ని వెతుకుతుందా?',
      'శిశువు వస్తువులను కదిలించడం, తట్టడం లేదా నోట్లో పెట్టడం ద్వారా పరిశీలిస్తుందా?',
      'శిశువు కొత్త వస్తువులపై ఆసక్తి చూపుతుందా?',
      'శిశువు పరిచయమైన వ్యక్తులను గుర్తించగలదా?',
    ],
    'SE': [
      'ఇతరులకు స్పందనగా శిశువు చిరునవ్వు ఇస్తుందా (సోషల్ స్మైల్)?',
      'సంప్రదింపుల సమయంలో శిశువు కంటి సంపర్కం చేస్తుందా?',
      'శిశువు సంరక్షకులతో ఆడటం ఆస్వాదిస్తుందా?',
      'శిశువు అన్యుల పట్ల భయాన్ని చూపుతుందా (6-9 నెలలు)?',
      'శిశువు వివిధ భావాలు (సంతోషం, బాధ, ఉత్సాహం) వ్యక్తం చేస్తుందా?',
    ],
  };
  static const Map<String, List<String>> _q12To24Te = {
    'GM': [
      'పిల్ల సహాయం లేకుండా స్వయంగా నడవగలదా?',
      'పిల్ల తరచుగా పడిపోకుండా పరుగెత్తగలదా?',
      'పిల్ల బంతిని ముందుకు తన్నగలదా?',
      'పిల్ల సహాయంతో కొద్ది మెట్లు ఎక్కగలదా?',
      'పిల్ల పాదాల వేళ్లపై నిలబడగలదా?',
    ],
    'FM': [
      '4 లేదా అంతకంటే ఎక్కువ బ్లాక్స్ కట్టగలదా?',
      'పుస్తకం పేజీలను ఒక్కొక్కటిగా తిప్పగలదా?',
      'క్రేయాన్‌తో స్వయంగా రాతలు/గీతలు వేయగలదా?',
      'చెంచాతో తినుతూ ఎక్కువగా చిందించకుండా ఉండగలదా?',
      'సాక్స్ లాంటి సులభమైన బట్టలు తీయగలదా?',
    ],
    'LC': [
      'కనీసం 20-50 అర్థవంతమైన పదాలు ఉపయోగించగలదా?',
      'రెండు పదాలను కలిపి చెప్పగలదా (ఉదా., "ఇంకా పాలు")?',
      'సులభమైన రెండు దశల సూచనలను అనుసరించగలదా?',
      'పేరు చెప్పినప్పుడు పరిచయమైన వస్తువును చూపించగలదా?',
      'పరిచయమైన వ్యక్తులు లేదా వస్తువుల పేర్లు చెప్పగలదా?',
    ],
    'COG': [
      'సమాన వస్తువులను జోడించగలదా?',
      'నటించుకుంటూ ఆడగలదా (బొమ్మకు తినిపించడం)?',
      'అడిగినప్పుడు శరీర భాగాలను గుర్తించగలదా?',
      'సరళ సమస్యలను పరిష్కరించగలదా (బొమ్మను అందుకోవడానికి వస్తువును కదలించడం)?',
      '“పెద్ద” మరియు “చిన్న” వంటి సులభమైన భావనలు అర్థం చేసుకోగలదా?',
    ],
    'SE': [
      'పరిచయమైన వ్యక్తుల పట్ల ప్రేమ చూపుతుందా?',
      'పెద్దల చర్యలను అనుకరిస్తుందా (ఉదా., ఊడ్చడం, ఫోన్‌లో మాట్లాడడం)?',
      'ఇతర పిల్లల పక్కన కలిసి ఆడగలదా (పారలల్ ప్లే)?',
      'ఏదైనా చేయలేనప్పుడు అసహనం చూపుతుందా?',
      'బాధపడినప్పుడు సంరక్షకుల దగ్గర ఓదార్పు కోరుతుందా?',
    ],
  };
  static const Map<String, List<String>> _q24To36Te = {
    'GM': [
      'పిల్ల తరచుగా పడిపోకుండా సాఫీగా పరుగెత్తగలదా?',
      'పిల్ల బాగా ఎక్కగలదా (ఉదా., ఫర్నిచర్ లేదా ప్లేగ్రౌండ్ పరికరాలపై)?',
      'పిల్ల ట్రైసైకిల్ పెడల్ చేయగలదా?',
      'పిల్ల ప్రత్యామ్నాయ పాదాలతో మెట్లు ఎక్కి దిగగలదా?',
      'పిల్ల రెండు కాళ్లతో కలిసి ముందుకు దూకగలదా?',
    ],
    'FM': [
      'పిల్ల సులభమైన వృత్తాన్ని కాపీ చేయగలదా?',
      'పిల్ల 6-8 బ్లాక్స్‌తో గోడ కట్టగలదా?',
      'పిల్ల తలుపు హ్యాండిల్స్ తిప్పగలదా లేదా మూతలు తిప్పి తెరవగలదా?',
      'పిల్ల చెంచా మరియు ఫోర్క్‌ను సరిగ్గా ఉపయోగించగలదా?',
      'పిల్ల టి-షర్ట్ లాంటి సులభమైన బట్టలు వేసుకోగలదా?',
    ],
    'LC': [
      'పిల్ల 3-4 పదాల వాక్యాలు మాట్లాడగలదా?',
      'పిల్ల తన పేరు మరియు వయస్సు చెప్పగలదా?',
      'పిల్ల మాటలు పరిచయమైన పెద్దలకు ఎక్కువసార్లు అర్థమయ్యేలా ఉంటాయా?',
      'పిల్ల మూడు దశల సూచనలను అనుసరించగలదా?',
      'పిల్ల సులభమైన "ఏమిటి" లేదా "ఎక్కడ" ప్రశ్నలకు సమాధానం చెప్పగలదా?',
    ],
    'COG': [
      'పిల్ల వస్తువులను రంగు లేదా ఆకారంతో వర్గీకరించగలదా?',
      'పిల్ల సులభమైన పజిళ్లను (3-4 భాగాలు) పూర్తిచేయగలదా?',
      'పిల్ల లెక్కల భావనను అర్థం చేసుకుంటుందా (ఉదా., 1-3 లెక్కించడం)?',
      'పిల్ల కథలోని కొన్ని భాగాలను గుర్తుంచుకోగలదా?',
      'పిల్ల "ఇప్పుడు" మరియు "తర్వాత" వంటి సమయ భావనలు అర్థం చేసుకోగలదా?',
    ],
    'SE': [
      'పిల్ల ఇతర పిల్లలతో సహకారంగా ఆడగలదా?',
      'పిల్ల ఆడేటప్పుడు మారుమారుగా అవకాశం ఇవ్వగలదా?',
      'పిల్ల వివిధ భావాలను చూపగలదా?',
      'పిల్ల తల్లిదండ్రుల నుంచి ఎక్కువ కష్టపడకుండా విడిపోగలదా?',
      'ఇతర పిల్లలు బాధపడితే పిల్ల ఆందోళన చూపుతుందా?',
    ],
  };
  static const Map<String, List<String>> _q36To48Te = {
    'GM': [
      'పిల్ల కొన్ని సెకన్ల పాటు ఒక కాళిపై దూకగలదా?',
      'పిల్ల ఉంచి బౌన్స్ చేసిన బంతిని ఎక్కువసార్లు పట్టగలదా?',
      'పిల్ల సహాయం లేకుండా ప్రత్యామ్నాయ పాదాలతో మెట్లు ఎక్కగలదా?',
      'పిల్ల స్కిప్ చేయగలదా లేదా ప్రయత్నించగలదా?',
      'పిల్ల కనీసం 5 సెకన్ల పాటు ఒక కాళిపై నిలబడగలదా?',
    ],
    'FM': [
      'పిల్ల చతురస్ర ఆకారాన్ని కాపీ చేయగలదా?',
      'పిల్ల కనీసం 3 శరీర భాగాలతో వ్యక్తి చిత్రాన్ని వేయగలదా?',
      'పిల్ల పిల్లలకు సరిపోయే కత్తెరతో కాగితాన్ని కత్తిరించగలదా?',
      'పిల్ల బటన్లు వేసి తీయగలదా?',
      'పిల్ల పెన్సిల్‌ను సరైన పట్టుతో పట్టగలదా?',
    ],
    'LC': [
      'పిల్ల 5-6 పదాల పూర్తి వాక్యాలు మాట్లాడగలదా?',
      'పిల్ల ఒక సంఘటన గురించి చిన్న కథ చెప్పగలదా?',
      'పిల్ల మాటలు పరిచయం లేని వారికి కూడా అర్థమయ్యేలా ఉంటాయా?',
      'పిల్ల "ఎందుకు" ప్రశ్నలకు సమాధానం చెప్పగలదా?',
      'పిల్ల క్లిష్టమైన సూచనలను (3-4 దశలు) అనుసరించగలదా?',
    ],
    'COG': [
      'పిల్ల కనీసం నాలుగు రంగులు సరిగా చెప్పగలదా?',
      'పిల్ల కనీసం 5 వస్తువులను సరిగా లెక్కించగలదా?',
      'పిల్ల "ఒకే" మరియు "వేరే" అనే భావనను అర్థం చేసుకోగలదా?',
      'పిల్ల సులభమైన 6-8 భాగాల పజిల్‌ను పూర్తిచేయగలదా?',
      'పిల్ల "మొదట, తరువాత, చివర" వంటి క్రమాన్ని అర్థం చేసుకోగలదా?',
    ],
    'SE': [
      'పిల్ల ఒంటరిగా ఆడటానికి కంటే ఇతర పిల్లలతో ఆడటాన్ని ఇష్టపడుతుందా?',
      'పిల్ల ఆటల్లో సులభమైన నియమాలు పాటించగలదా?',
      'పిల్ల ఇతరుల పట్ల సహానుభూతి చూపుతుందా?',
      'పిల్ల 3 ఏళ్ల వయస్సుతో పోలిస్తే భావాలను మెరుగ్గా నియంత్రించగలదా?',
      'పిల్ల రోజువారీ పనుల్లో స్వతంత్రత చూపుతుందా (శౌచక్రియ, దుస్తులు)?',
    ],
  };
  static const Map<String, List<String>> _q48To60Te = {
    'GM': [
      'పిల్ల సాఫీగా స్కిప్ చేయగలదా?',
      'పిల్ల కనీసం 10 సెకన్ల పాటు ఒక కాళిపై సమతుల్యం నిలబడగలదా?',
      'పిల్ల ఒక కాళిపై పలుమార్లు ముందుకు దూకగలదా?',
      'పిల్ల చిన్న బంతిని రెండు చేతులతో పట్టగలదా?',
      'పిల్ల సులభమైన సమూహ ఆటల్లో పాల్గొనగలదా (పరుగెత్తడం, చేజింగ్)?',
    ],
    'FM': [
      'పిల్ల త్రిభుజ ఆకారాన్ని కాపీ చేయగలదా?',
      'పిల్ల కనీసం 6 శరీర భాగాలతో వ్యక్తి చిత్రాన్ని వేయగలదా?',
      'పిల్ల కొన్ని అక్షరాలు లేదా సంఖ్యలు రాయగలదా?',
      'పిల్ల ఎక్కువగా గీతల లోపల రంగు వేయగలదా?',
      'పిల్ల సాదా ముడి కట్టగలదా (లేదా షూలేస్ కట్టడానికి ప్రయత్నించగలదా)?',
    ],
    'LC': [
      'పిల్ల స్పష్టంగా, వ్యాకరణపరంగా సరైన పూర్తి వాక్యాలు మాట్లాడగలదా?',
      'పిల్ల ఇటీవలి సంఘటనను వివరంగా చెప్పగలదా?',
      'పిల్ల భవిష్యత్ కాలాన్ని అర్థం చేసుకుని ఉపయోగించగలదా (ఉదా., "నేను వెళ్తాను")?',
      'పిల్ల బహుళ దశల సూచనలను (4-5 దశలు) అనుసరించగలదా?',
      'పిల్ల కథ విన్న తర్వాత ప్రశ్నలకు సమాధానం చెప్పగలదా?',
    ],
    'COG': [
      'పిల్ల కనీసం 10 వస్తువులను సరిగా లెక్కించగలదా?',
      'పిల్ల కొన్ని అక్షరాలు లేదా సంఖ్యలను గుర్తించగలదా?',
      'పిల్ల "నిన్న, ఈ రోజు, రేపు" వంటి సమయ భావనలను అర్థం చేసుకోగలదా?',
      'పిల్ల సులభమైన తార్కిక సమస్యలను పరిష్కరించగలదా?',
      'పిల్ల రెండు వస్తువుల మధ్య పోలికను గుర్తించగలదా (ఉదా., ఆపిల్ మరియు అరటి పండ్లు)?',
    ],
    'SE': [
      'పిల్ల ఇతర పిల్లలతో సహకరించి పంచుకోగలదా?',
      'పిల్ల నియమాలున్న ఆటల్లో నియమాలు పాటించగలదా?',
      'పిల్ల భావాలను కేవలం చర్యలతో కాకుండా మాటలతో వ్యక్తం చేయగలదా?',
      'పిల్ల చిన్న నిరాశలను ఎక్కువ టాంట్రమ్స్ లేకుండా ఎదుర్కోగలదా?',
      'పిల్ల చిన్న పనులకు బాధ్యత చూపుతుందా (ఉదా., బొమ్మలు సర్దడం)?',
    ],
  };
  static const Map<String, List<String>> _q60To72Te = {
    'GM': [
      'పిల్ల సమన్వయంతో మరియు లయతో స్కిప్ చేయగలదా?',
      'పిల్ల ట్రైనింగ్ వీల్స్ తో లేదా లేకుండా సైకిల్ తొక్కగలదా?',
      'పిల్ల జంప్ రోప్ చేయగలదా లేదా సమన్వయ దూకుడు ప్రయత్నించగలదా?',
      'పిల్ల చిన్న బంతిని ఖచ్చితంగా విసిరి పట్టగలదా?',
      'పిల్ల సరళ జట్టు క్రీడల్లో పాల్గొనగలదా?',
    ],
    'FM': [
      'పిల్ల తన పూర్తి పేరును స్పష్టంగా రాయగలదా?',
      'పిల్ల అనేక వివరాలతో గుర్తించదగ్గ చిత్రాలు వేయగలదా?',
      'పిల్ల సూటిగా లేదా వంకరగా ఉన్న గీతల వెంట కత్తిరించగలదా?',
      'పిల్ల సరైన పెన్సిల్ పట్టును నిరంతరం ఉపయోగించగలదా?',
      'పిల్ల సులభమైన క్రాఫ్ట్స్ పూర్తిచేయగలదా (కాగితం మడతలు, అతికించడం)?',
    ],
    'LC': [
      'పిల్ల స్పష్టమైన ఉచ్చారణతో సరళంగా మాట్లాడగలదా?',
      'పిల్ల సులభమైన పదాలు లేదా చిన్న వాక్యాలు చదవగలదా?',
      'పిల్ల "ఎలా" మరియు "ఎందుకు" ప్రశ్నలకు స్పష్టంగా సమాధానం చెప్పగలదా?',
      'పిల్ల చిన్న కథను క్రమబద్ధంగా మళ్లీ చెప్పగలదా?',
      'పిల్ల తరగతి సూచనలను స్వతంత్రంగా అనుసరించగలదా?',
    ],
    'COG': [
      'పిల్ల 20 వరకు సరిగ్గా లెక్కించగలదా?',
      'పిల్ల సులభమైన జోడింపు లేదా తీసివేత చేయగలదా (ఉదా., 2 + 1)?',
      'పిల్ల వారంలో రోజుల పేర్లు గుర్తించగలదా?',
      'పిల్ల కారణం-ఫలితం సంబంధాలను అర్థం చేసుకోగలదా?',
      'పిల్ల వస్తువులను గుంపులుగా వర్గీకరించగలదా (ఉదా., జంతువులు, వాహనాలు)?',
    ],
    'SE': [
      'పిల్ల స్నేహాలు చేసుకొని కొనసాగించగలదా?',
      'పిల్ల చిన్న గొడవలను పెద్దల సహాయం లేకుండా పరిష్కరించగలదా?',
      'పిల్ల పాఠశాల నియమాలను స్థిరంగా పాటించగలదా?',
      'పిల్ల భిన్న పరిస్థితుల్లో భావాలను సరైన విధంగా వ్యక్తం చేయగలదా?',
      'పిల్ల పనులు పూర్తి చేయడంలో ఆత్మవిశ్వాసం చూపుతుందా?',
    ],
  };

  // Hindi placeholders (filled in follow-up patches)
  static const Map<String, List<String>> _q0To12Hi = {
    'GM': [
      'क्या शिशु दोनों हाथ और पैर समान रूप से हिलाता/हिलाती है?',
      'क्या शिशु पेट के बल लेटकर सिर उठाता/उठाती है (टमी टाइम)?',
      'क्या शिशु बिना सहारे के सिर स्थिर रख सकता/सकती है?',
      'क्या शिशु करवट बदल सकता/सकती है (पेट से पीठ या पीठ से पेट)?',
      'क्या शिशु सहारे से बैठ सकता/सकती है?',
    ],
    'FM': [
      'क्या शिशु हाथ में आपकी उंगली रखने पर पकड़ता/पकड़ती है?',
      'क्या शिशु हाथों को मुंह तक ले जाता/जाती है?',
      'क्या शिशु सामने रखी खिलौने तक पहुंच सकता/सकती है?',
      'क्या शिशु खिलौने को एक हाथ से दूसरे हाथ में बदल सकता/सकती है?',
      'क्या शिशु पूरे हाथ से वस्तु पकड़ता/पकड़ती है (पामर ग्रैस्प)?',
    ],
    'LC': [
      'क्या शिशु आवाजों या तेज़ शोर पर प्रतिक्रिया देता/देती है?',
      'क्या शिशु परिचित आवाज़ की ओर मुड़ता/मुड़ती है?',
      'क्या शिशु कूइंग या बबलिंग जैसी आवाज़ें करता/करती है?',
      'क्या शिशु हंसता/हंसती है या चीखता/चीखती है?',
      'क्या शिशु नाम पुकारने पर प्रतिक्रिया देता/देती है?',
    ],
    'COG': [
      'क्या शिशु चलते हुए वस्तु को आंखों से फॉलो करता/करती है?',
      'क्या शिशु आंशिक रूप से छुपी खिलौने को ढूंढता/ढूंढती है?',
      'क्या शिशु वस्तुओं को हिलाकर, ठोककर या मुंह में डालकर जांचता/जांचती है?',
      'क्या शिशु नई वस्तुओं के प्रति जिज्ञासा दिखाता/दिखाती है?',
      'क्या शिशु परिचित लोगों को पहचानता/पहचानती है?',
    ],
    'SE': [
      'क्या शिशु दूसरों पर प्रतिक्रिया में मुस्कुराता/मुस्कुराती है (सोशल स्माइल)?',
      'क्या शिशु बातचीत के दौरान आंखों का संपर्क करता/करती है?',
      'क्या शिशु देखभाल करने वालों के साथ खेलना पसंद करता/करती है?',
      'क्या शिशु अजनबियों से डर दिखाता/दिखाती है (लगभग 6-9 महीने)?',
      'क्या शिशु अलग-अलग भावनाएं (खुश, उदास, उत्साहित) दिखाता/दिखाती है?',
    ],
  };
  static const Map<String, List<String>> _q12To24Hi = {
    'GM': [
      'क्या बच्चा बिना सहारे के स्वतंत्र रूप से चल सकता/सकती है?',
      'क्या बच्चा बार-बार गिरने के बिना दौड़ सकता/सकती है?',
      'क्या बच्चा गेंद को आगे की ओर लात मार सकता/सकती है?',
      'क्या बच्चा सहारे से कुछ सीढ़ियां चढ़ सकता/सकती है?',
      'क्या बच्चा पंजों के बल खड़ा हो सकता/सकती है?',
    ],
    'FM': [
      'क्या बच्चा 4 या उससे अधिक ब्लॉक्स जमा सकता/सकती है?',
      'क्या बच्चा किताब के पन्ने एक-एक करके पलट सकता/सकती है?',
      'क्या बच्चा क्रेयॉन से अपने आप रेखाएं/स्क्रिबल कर सकता/सकती है?',
      'क्या बच्चा कम गिराए हुए चम्मच से खा सकता/सकती है?',
      'क्या बच्चा सरल कपड़े (जैसे मोज़े) निकाल सकता/सकती है?',
    ],
    'LC': [
      'क्या बच्चा कम से कम 20-50 अर्थपूर्ण शब्द बोल सकता/सकती है?',
      'क्या बच्चा दो शब्दों को जोड़ सकता/सकती है (जैसे "और दूध")?',
      'क्या बच्चा सरल दो-चरणीय निर्देशों का पालन कर सकता/सकती है?',
      'क्या बच्चा नाम लेने पर परिचित वस्तुओं की ओर इशारा कर सकता/सकती है?',
      'क्या बच्चा परिचित लोगों या वस्तुओं के नाम बता सकता/सकती है?',
    ],
    'COG': [
      'क्या बच्चा समान वस्तुओं को मिलान कर सकता/सकती है?',
      'क्या बच्चा कल्पनात्मक खेल करता/करती है (जैसे गुड़िया को खिलाना)?',
      'क्या बच्चा पूछने पर शरीर के अंग पहचान सकता/सकती है?',
      'क्या बच्चा सरल समस्याओं का समाधान कर सकता/सकती है (खिलौना तक पहुंचने के लिए वस्तु हटाना)?',
      'क्या बच्चा "बड़ा" और "छोटा" जैसी सरल अवधारणाएं समझता/समझती है?',
    ],
    'SE': [
      'क्या बच्चा परिचित लोगों के प्रति स्नेह दिखाता/दिखाती है?',
      'क्या बच्चा बड़ों की गतिविधियों की नकल करता/करती है (जैसे झाड़ू लगाना, फोन पर बात करना)?',
      'क्या बच्चा अन्य बच्चों के साथ समानांतर खेल खेलता/खेलती है?',
      'क्या बच्चा कुछ न कर पाने पर निराशा दिखाता/दिखाती है?',
      'क्या बच्चा परेशान होने पर देखभाल करने वालों से सांत्वना चाहता/चाहती है?',
    ],
  };
  static const Map<String, List<String>> _q24To36Hi = {
    'GM': [
      'क्या बच्चा बिना बार-बार गिरें आसानी से दौड़ सकता/सकती है?',
      'क्या बच्चा अच्छी तरह चढ़ सकता/सकती है (जैसे फर्नीचर या खेल उपकरण पर)?',
      'क्या बच्चा ट्राइसाइकिल पैडल कर सकता/सकती है?',
      'क्या बच्चा बारी-बारी से पैर रखकर सीढ़ियां चढ़-उतर सकता/सकती है?',
      'क्या बच्चा दोनों पैरों से साथ में आगे कूद सकता/सकती है?',
    ],
    'FM': [
      'क्या बच्चा सरल वृत्त की नकल कर सकता/सकती है?',
      'क्या बच्चा 6-8 ब्लॉक्स का टॉवर बना सकता/सकती है?',
      'क्या बच्चा दरवाजे के हैंडल घुमा सकता/सकती है या ढक्कन खोल सकता/सकती है?',
      'क्या बच्चा चम्मच और कांटे का सही उपयोग कर सकता/सकती है?',
      'क्या बच्चा सरल कपड़े (जैसे टी-शर्ट) पहन सकता/सकती है?',
    ],
    'LC': [
      'क्या बच्चा 3-4 शब्दों के वाक्य बोल सकता/सकती है?',
      'क्या बच्चा अपना नाम और उम्र बता सकता/सकती है?',
      'क्या बच्चे की बात परिचित बड़ों को अधिकतर समझ आती है?',
      'क्या बच्चा तीन-चरणीय निर्देशों का पालन कर सकता/सकती है?',
      'क्या बच्चा सरल "क्या" या "कहां" प्रश्नों का उत्तर दे सकता/सकती है?',
    ],
    'COG': [
      'क्या बच्चा वस्तुओं को रंग या आकार के अनुसार छांट सकता/सकती है?',
      'क्या बच्चा सरल पहेलियां (3-4 टुकड़े) पूरी कर सकता/सकती है?',
      'क्या बच्चा गिनती की अवधारणा समझता/समझती है (जैसे 1-3 गिनना)?',
      'क्या बच्चा कहानी के कुछ हिस्से याद रख सकता/सकती है?',
      'क्या बच्चा "अब" और "बाद में" जैसी समय अवधारणाएं समझता/समझती है?',
    ],
    'SE': [
      'क्या बच्चा अन्य बच्चों के साथ सहयोग से खेलता/खेलती है?',
      'क्या बच्चा खेल के दौरान बारी ले सकता/सकती है?',
      'क्या बच्चा विभिन्न भावनाएं दिखाता/दिखाती है?',
      'क्या बच्चा माता-पिता से अत्यधिक परेशान हुए बिना अलग हो सकता/सकती है?',
      'क्या बच्चा किसी दूसरे बच्चे के दुखी होने पर चिंता दिखाता/दिखाती है?',
    ],
  };
  static const Map<String, List<String>> _q36To48Hi = {
    'GM': [
      'क्या बच्चा कुछ सेकंड के लिए एक पैर पर कूद सकता/सकती है?',
      'क्या बच्चा उछली हुई गेंद को अधिकतर पकड़ सकता/सकती है?',
      'क्या बच्चा बिना सहारे के बारी-बारी से पैर रखकर सीढ़ियां चढ़ सकता/सकती है?',
      'क्या बच्चा स्किप कर सकता/सकती है या कोशिश कर सकता/सकती है?',
      'क्या बच्चा कम से कम 5 सेकंड तक एक पैर पर खड़ा रह सकता/सकती है?',
    ],
    'FM': [
      'क्या बच्चा वर्ग (चौकोर) की नकल कर सकता/सकती है?',
      'क्या बच्चा कम से कम 3 शरीर के हिस्सों के साथ व्यक्ति का चित्र बना सकता/सकती है?',
      'क्या बच्चा बच्चों की सुरक्षित कैंची से कागज काट सकता/सकती है?',
      'क्या बच्चा बटन लगाना और खोलना कर सकता/सकती है?',
      'क्या बच्चा पेंसिल सही पकड़ के साथ पकड़ सकता/सकती है?',
    ],
    'LC': [
      'क्या बच्चा 5-6 शब्दों के पूर्ण वाक्य बोल सकता/सकती है?',
      'क्या बच्चा किसी घटना के बारे में छोटा सा किस्सा बता सकता/सकती है?',
      'क्या बच्चे की बात अनजान लोगों को भी समझ आती है?',
      'क्या बच्चा "क्यों" प्रश्नों का उत्तर दे सकता/सकती है?',
      'क्या बच्चा जटिल निर्देशों (3-4 चरण) का पालन कर सकता/सकती है?',
    ],
    'COG': [
      'क्या बच्चा कम से कम चार रंग सही पहचान सकता/सकती है?',
      'क्या बच्चा कम से कम 5 वस्तुओं को सही गिन सकता/सकती है?',
      'क्या बच्चा "समान" और "अलग" की अवधारणा समझता/समझती है?',
      'क्या बच्चा 6-8 टुकड़ों की सरल पहेली पूरी कर सकता/सकती है?',
      'क्या बच्चा क्रम (पहले, फिर, अंत में) समझता/समझती है?',
    ],
    'SE': [
      'क्या बच्चा अकेले की बजाय अन्य बच्चों के साथ खेलना पसंद करता/करती है?',
      'क्या बच्चा खेलों में सरल नियमों का पालन कर सकता/सकती है?',
      'क्या बच्चा दूसरों के प्रति सहानुभूति दिखाता/दिखाती है?',
      'क्या बच्चा 3 वर्ष की उम्र की तुलना में भावनाओं को बेहतर नियंत्रित कर सकता/सकती है?',
      'क्या बच्चा दैनिक गतिविधियों (शौच, कपड़े पहनना) में स्वतंत्रता दिखाता/दिखाती है?',
    ],
  };
  static const Map<String, List<String>> _q48To60Hi = {
    'GM': [
      'क्या बच्चा आसानी से स्किप कर सकता/सकती है?',
      'क्या बच्चा कम से कम 10 सेकंड तक एक पैर पर संतुलन बना सकता/सकती है?',
      'क्या बच्चा एक पैर पर कई बार आगे कूद सकता/सकती है?',
      'क्या बच्चा छोटी गेंद दोनों हाथों से पकड़ सकता/सकती है?',
      'क्या बच्चा सरल समूह शारीरिक खेलों में भाग ले सकता/सकती है?',
    ],
    'FM': [
      'क्या बच्चा त्रिभुज की नकल कर सकता/सकती है?',
      'क्या बच्चा कम से कम 6 शरीर के हिस्सों के साथ व्यक्ति का चित्र बना सकता/सकती है?',
      'क्या बच्चा कुछ अक्षर या अंक लिख सकता/सकती है?',
      'क्या बच्चा अधिकांशतः रेखाओं के भीतर रंग भर सकता/सकती है?',
      'क्या बच्चा सरल गांठ बांध सकता/सकती है (या जूते के फीते बांधने की कोशिश कर सकता/सकती है)?',
    ],
    'LC': [
      'क्या बच्चा स्पष्ट और व्याकरण सही पूर्ण वाक्य बोल सकता/सकती है?',
      'क्या बच्चा हाल की घटना का विस्तृत वर्णन कर सकता/सकती है?',
      'क्या बच्चा भविष्य काल समझ सकता/सकती है और उपयोग कर सकता/सकती है (जैसे "मैं जाऊंगा")?',
      'क्या बच्चा बहु-चरणीय निर्देशों (4-5 चरण) का पालन कर सकता/सकती है?',
      'क्या बच्चा कहानी सुनने के बाद प्रश्नों का उत्तर दे सकता/सकती है?',
    ],
    'COG': [
      'क्या बच्चा कम से कम 10 वस्तुओं को सही गिन सकता/सकती है?',
      'क्या बच्चा कुछ अक्षर या अंक पहचान सकता/सकती है?',
      'क्या बच्चा समय की बुनियादी अवधारणाएं (कल, आज, कल) समझता/समझती है?',
      'क्या बच्चा सरल तर्क समस्याओं को हल कर सकता/सकती है?',
      'क्या बच्चा दो वस्तुओं में समानता पहचान सकता/सकती है (जैसे सेब और केला फल हैं)?',
    ],
    'SE': [
      'क्या बच्चा अन्य बच्चों के साथ सहयोग और साझा कर सकता/सकती है?',
      'क्या बच्चा संरचित खेलों में नियमों का पालन कर सकता/सकती है?',
      'क्या बच्चा केवल क्रियाओं से नहीं बल्कि शब्दों से भावनाएं व्यक्त कर सकता/सकती है?',
      'क्या बच्चा छोटी निराशाओं को बड़े tantrums के बिना संभाल सकता/सकती है?',
      'क्या बच्चा छोटे कार्यों की जिम्मेदारी दिखाता/दिखाती है (जैसे खिलौने समेटना)?',
    ],
  };
  static const Map<String, List<String>> _q60To72Hi = {
    'GM': [
      'क्या बच्चा ताल और समन्वय के साथ स्किप कर सकता/सकती है?',
      'क्या बच्चा प्रशिक्षण पहियों के साथ या बिना साइकिल चला सकता/सकती है?',
      'क्या बच्चा रस्सी कूद सकता/सकती है या समन्वित कूदने की कोशिश कर सकता/सकती है?',
      'क्या बच्चा छोटी गेंद को सही तरीके से फेंक और पकड़ सकता/सकती है?',
      'क्या बच्चा टीम शारीरिक गतिविधियों में भाग ले सकता/सकती है?',
    ],
    'FM': [
      'क्या बच्चा अपना पूरा नाम साफ-साफ लिख सकता/सकती है?',
      'क्या बच्चा कई विवरणों के साथ पहचानने योग्य चित्र बना सकता/सकती है?',
      'क्या बच्चा सीधी या घुमावदार रेखा के साथ सही तरीके से काट सकता/सकती है?',
      'क्या बच्चा सही पेंसिल पकड़ लगातार उपयोग कर सकता/सकती है?',
      'क्या बच्चा सरल क्राफ्ट पूरा कर सकता/सकती है (कागज मोड़ना, आकार चिपकाना)?',
    ],
    'LC': [
      'क्या बच्चा स्पष्ट उच्चारण के साथ धाराप्रवाह बोल सकता/सकती है?',
      'क्या बच्चा सरल शब्द या छोटे वाक्य पढ़ सकता/सकती है?',
      'क्या बच्चा "कैसे" और "क्यों" प्रश्नों का स्पष्ट उत्तर दे सकता/सकती है?',
      'क्या बच्चा छोटी कहानी को क्रम में दोहरा सकता/सकती है?',
      'क्या बच्चा कक्षा के निर्देश स्वतंत्र रूप से पालन कर सकता/सकती है?',
    ],
    'COG': [
      'क्या बच्चा 20 तक सही गिन सकता/सकती है?',
      'क्या बच्चा सरल जोड़ या घटाव कर सकता/सकती है (जैसे 2 + 1)?',
      'क्या बच्चा सप्ताह के दिनों को पहचान सकता/सकती है?',
      'क्या बच्चा कारण-परिणाम संबंध समझता/समझती है?',
      'क्या बच्चा वस्तुओं को समूहों में वर्गीकृत कर सकता/सकती है (जैसे जानवर, वाहन)?',
    ],
    'SE': [
      'क्या बच्चा दोस्त बनाता/बनाती है और उन्हें बनाए रख सकता/सकती है?',
      'क्या बच्चा छोटे झगड़ों को कम से कम बड़ों की मदद से सुलझा सकता/सकती है?',
      'क्या बच्चा स्कूल के नियमों का नियमित रूप से पालन करता/करती है?',
      'क्या बच्चा विभिन्न परिस्थितियों में भावनाओं को उचित तरीके से व्यक्त करता/करती है?',
      'क्या बच्चा कार्यों को स्वतंत्र रूप से पूरा करने में आत्मविश्वास दिखाता/दिखाती है?',
    ],
  };
}
