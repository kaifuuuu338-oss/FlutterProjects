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

  // 0-12 months (English) - Using 3-6 months questions
  static const Map<String, List<String>> _q0To12En = {
    'GM': [
      'SF002: When lying on his/her back, does your child move his/her arms and legs?',
      'SF025: When your child is on his/her stomach, can he/she turn his/her head to the side?',
      'SF029: Can your child hold his/her head steady for at least a few seconds?',
      'SF030: When held in a sitting position, can your child hold his/her head steady and straight?',
      'SF031: When your child is on his/her stomach, can he/she hold his/her head up off the ground?',
      'SF033: When your child is on his/her tummy, can your child hold his/her head straight up?',
      'SF034: Can your child roll from his/her back to stomach or stomach to side?',
      'SF038: Can your child sit with support?',
      'SF041: When lying on his/her stomach, can your child hold his/her head and chest off the ground?',
      'SF044: Can your child roll from his/her back to stomach or stomach to back?',
      'SF047: Can your child hold him/herself in a sitting position without help?',
      'SF050: Can your child lean on his/her hands while sitting?',
      'SF055: Can your child maintain a standing position while holding onto a person or object?',
      'SF057: Can your child pull him-/herself up from the floor while holding on to something?',
      'SF059: Can your child walk several steps while holding onto a person or object?',
      'SF060: While holding onto furniture, does your child bend down and pick up a small object?',
      'SF061: While holding onto furniture, does your child squat with control?',
      'SF064: Can your child stand up without holding onto anything?',
      'SF066: Can your child maintain a standing position on his/her own?',
      'SF068: Can your child climb onto an object?',
      'SF070: Can your child bend down or squat to pick up an object and stand up again?',
      'SF074: Can your child take several steps forward without holding onto any person or object?',
    ],
    'FM': [
      'SF005: Does your child hold your finger when you put it in his/her hand?',
      'SF015: Does your child try to swipe at or reach for toys or objects?',
      'SF016: Does your child grasp a toy or object when you place it in his/her hand?',
      'SF018: Does your child hold and shake a toy placed in his/her hand?',
      'SF035: Does your child reach out for objects and grasp them?',
      'SF036: Does your child transfer an object from one hand to the other?',
      'SF037: Does your child rake small objects toward him-/herself using his/her fingers?',
      'SF039: Does your child use his/her fingers to feed him-/herself?',
      'SF040: Does your child pick up small objects using his/her thumb and one finger (pincer grasp)?',
      'SF043: Does your child deliberately drop an object into a container?',
      'SF045: Does your child use his/her hands together to hold or manipulate objects?',
      'SF049: Can your child pick up a small object using his/her thumb and one finger without resting arm on surface?',
      'SF051: Does your child bang two objects together?',
      'SF052: Does your child clap hands?',
      'SF053: Does your child point at objects using one finger?',
    ],
    'LC': [
      'SF008: Does your child try to move his/her head (or eyes) to follow an object or person?',
      'SF010: Does your child look at a person when that person starts talking or making noise?',
      'SF012: When you talk to your child, does he/she smile, make noises or move arms, legs or trunk in response?',
      'SF014: Does your child turn his/her head towards your voice or some other noise?',
      'SF023: Does your child laugh?',
      'SF026: Does your child make sounds (not crying) when looking at toys or people?',
      'SF032: Does your child show interest in new objects that are put in front of him/her by reaching out for them?',
      'SF071: Can your child follow a simple spoken command or direction without you making a gesture?',
      'SF072: Can your child fetch something when asked?',
      'SF082: Can your child greet people either by giving his/her hand or saying "Hello"?',
    ],
    'COG': [
      'SF006: Does your child look at and focus on objects in front of him/her?',
      'SF042: If an object falls to the ground out of view, does your child look for it?',
      'SF046: Does your child look for an object of interest when it is removed from sight or hidden from him/her?',
      'SF048: Does your child intentionally move or change his/her position to get objects that are out of reach?',
      'SF058: Does your child stop what he/she is doing when you say "Stop!", even if just for a second?',
    ],
    'SE': [
      'SF001: Does your child smile?',
      'SF003: Does your child look at your face when you speak to him/her?',
      'SF004: Does your child cry when he/she is hungry, wet, tired or wants to be held?',
      'SF009: Does your child smile when you smile at or talk with him/her?',
      'SF011: Does your child stop crying or calm down when you come into the room after being out of sight or when you pick him/her up?',
      'SF013: When you are about to pick up your child, does he/she act happy or excited?',
      'SF019: Does your child move excitedly when a known person enters the room?',
      'SF020: Does your child make noise or gestures to get your attention?',
      'SF021: If you play a game with your child, does he/she respond with interest?',
      'SF022: Does your child recognize you or other family members?',
      'SF024: Does your child smile or become excited when seeing someone familiar?',
      'SF027: Is your child interested when he/she sees other children playing?',
      'SF063: Even if your child is unable to do singing games, does he/she enjoy them?',
    ],
  };

  // 13-24 months (English) - 12-24 months clinical milestones
  static const Map<String, List<String>> _q12To24En = {
    'GM': [
      'SF076: Can your child stand up from sitting and take several steps forward?',
      'SF079: Can your child move around by walking rather than crawling?',
      'SF080: Can your child walk well, with coordination?',
      'SF083: Can your child kick a ball forward using his/her foot?',
      'SF089: Can your child run well without falling?',
    ],
    'FM': [
      'SF054: Does your child use a spoon with some spilling?',
      'SF056: Can your child stack two small blocks on top of each other?',
      'SF062: Can your child scribble on paper with a crayon or pencil?',
      'SF067: Can your child stack three small blocks on top of each other?',
      'SF069: Can your child turn pages of a book?',
      'SF075: Can your child stack four or more small blocks on top of each other?',
    ],
    'LC': [
      'SF104: Does your child say at least one meaningful word (besides "mama" or "dada")?',
      'SF105: Does your child combine two words together?',
      'SF106: Can your child say his/her own name when asked?',
      'SF107: Can your child name at least one object when shown a picture?',
    ],
    'COG': [
      'SF071: Can your child follow a simple spoken command or direction without you making a gesture?',
      'SF072: Can your child fetch something when asked?',
      'SF085: Can your child follow directions with more than 1 step?',
      'SF087: Can your child identify at least 7 objects?',
    ],
    'SE': [
      'SF073: Does your child share with others?',
      'SF082: Can your child greet people either by giving his/her hand or saying "Hello"?',
      'SF093: Does your child show independence?',
    ],
  };

  // 25-36 months (English) - 24-36 months clinical milestones
  static const Map<String, List<String>> _q24To36En = {
    'GM': [
      'SF091: While standing, can your child kick a ball by swinging his/her leg forward?',
      'SF096: Can your child walk on an uneven surface without falling?',
      'SF108: Can your child jump with both feet leaving the ground?',
      'SF126: Can your child stand on one foot WITHOUT any support?',
    ],
    'FM': [
      'SF077: Can your child draw a straight line?',
      'SF078: Can your child copy a circle?',
      'SF081: Can your child use scissors to cut paper?',
      'SF084: Can your child copy a cross (+) shape?',
      'SF086: Can your child draw a person with at least two body parts?',
      'SF088: Can your child fasten and unfasten large buttons?',
      'SF094: Can your child hold a pencil correctly between thumb and fingers?',
      'SF095: Can your child copy a square?',
      'SF097: Can your child draw a recognizable picture?',
      'SF098: Can your child fasten and unfasten small buttons?',
      'SF099: Can your child tie a knot?',
      'SF100: Can your child cut along a straight line with scissors?',
      'SF101: Can your child draw a triangle?',
    ],
    'LC': [
      'SF085: Can your child follow directions with more than 1 step?',
      'SF087: Can your child identify at least 7 objects?',
      'SF109: Can your child speak in sentences of 3 or more words?',
      'SF110: Can your child answer simple questions appropriately?',
      'SF112: Can your child tell a short story about something that happened?',
      'SF113: Can your child sing a short song or repeat parts of a rhyme from memory?',
    ],
    'COG': [
      'SF115: Can your child identify at least 3 colours correctly?',
      'SF116: Can your child count at least 3 objects correctly?',
      'SF120: Can your child answer simple "Why" questions appropriately?',
      'SF123: Can your child follow rules in simple games?',
    ],
    'SE': [
      'SF102: Does your child help out around the house with simple chores?',
      'SF111: Does your child show respect around elders?',
      'SF118: Can your child take turns while playing with other children?',
      'SF119: Can your child express feelings such as happy, sad or angry using words?',
      'SF124: Can your child separate easily from caregivers without extreme distress?',
      'SF125: Can your child play cooperatively with other children?',
    ],
  };

  // 37-48 months (English) - 3-4 years clinical milestones
  static const Map<String, List<String>> _q36To48En = {
    'GM': [
      'Runs smoothly without frequent falls?',
      'Jumps forward with both feet?',
      'Climbs stairs alternating feet?',
      'Balances on one foot for 3–5 seconds?',
      'Frequent falls or poor coordination? (Red Flag)',
    ],
    'FM': [
      'Copies straight lines and circles?',
      'Strings large beads?',
      'Builds tower of 8–10 blocks?',
      'Holds crayon with tripod grasp?',
      'Cannot manipulate small objects? (Red Flag)',
    ],
    'LC': [
      'Speaks in 3–4 word sentences?',
      'Names familiar objects and people?',
      'Asks simple questions?',
      'Follows 2–3 step commands?',
      'Speech mostly unintelligible? (Red Flag)',
    ],
    'COG': [
      'Completes 4–6 piece puzzles?',
      'Sorts objects by shape or color?',
      'Engages in imaginative play?',
      'Understands simple concepts (big/small, in/out)?',
      'No pretend or problem-solving play? (Red Flag)',
    ],
    'SE': [
      'Plays cooperatively with peers?',
      'Takes turns during play?',
      'Shows empathy toward others?',
      'Follows simple group rules?',
      'Severe aggression or social withdrawal? (Red Flag)',
    ],
  };

  // 49-60 months (English) - 4-5 years clinical milestones
  static const Map<String, List<String>> _q48To60En = {
    'GM': [
      'Hops on one foot?',
      'Runs smoothly with good coordination?',
      'Climbs stairs alternating feet confidently?',
      'Balances on one foot for 8–10 seconds?',
      'Frequent falls or major coordination difficulty? (Red Flag)',
    ],
    'FM': [
      'Copies square and cross?',
      'Draws a person with 4–6 body parts?',
      'Cuts along straight and curved lines?',
      'Uses pencil with mature tripod grasp?',
      'Cannot copy basic shapes or control pencil? (Red Flag)',
    ],
    'LC': [
      'Speaks clearly in full sentences?',
      'Tells simple stories?',
      'Answers "why" and "how" questions?',
      'Understands positional and descriptive words?',
      'Speech unclear to unfamiliar listeners? (Red Flag)',
    ],
    'COG': [
      'Counts to 10 or more?',
      'Identifies basic colors and shapes?',
      'Completes 6–8 piece puzzles?',
      'Understands same and different?',
      'Cannot complete structured problem-solving tasks? (Red Flag)',
    ],
    'SE': [
      'Plays cooperatively in group games?',
      'Follows classroom rules?',
      'Shows empathy toward peers?',
      'Manages frustration with minimal support?',
      'Extreme aggression, withdrawal, or emotional dysregulation? (Red Flag)',
    ],
  };

  // 61-72 months (English) - 5-6 years milestone questions
  static const Map<String, List<String>> _q60To72En = {
    'GM': [
      'Can the child skip and maintain balance during play?',
      'Can the child skip smoothly with coordination?',
      'Can the child ride a bicycle with or without training wheels?',
      'Can the child jump rope or attempt coordinated jumping?',
      'Can the child throw and catch a small ball accurately?',
    ],
    'FM': [
      'Can the child copy simple shapes like a square?',
      'Can the child write their own name clearly?',
      'Can the child draw recognizable pictures with details?',
      'Can the child cut along a straight or curved line?',
      'Can the child use proper pencil grip consistently?',
    ],
    'LC': [
      'Can the child speak clearly in full sentences?',
      'Can the child speak fluently with clear pronunciation?',
      'Can the child read simple words or short sentences?',
      'Can the child understand and answer how and why questions?',
      'Can the child retell a short story in sequence?',
    ],
    'COG': [
      'Can the child recognize letters or numbers?',
      'Can the child count up to 20 correctly?',
      'Can the child perform simple addition or subtraction?',
      'Can the child identify days of the week?',
      'Can the child categorize objects into groups?',
    ],
    'SE': [
      'Does the child cooperate with peers and control emotions?',
      'Does the child make and maintain friendships?',
      'Can the child resolve small conflicts with minimal help?',
      'Does the child follow school rules consistently?',
      'Does the child show confidence in completing tasks?',
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
