class NeuroQuestion {
  final String text;
  final int weight;

  const NeuroQuestion({
    required this.text,
    required this.weight,
  });
}

class NeuroQuestionSet {
  final List<NeuroQuestion> autism;
  final List<NeuroQuestion> adhd;
  final List<NeuroQuestion> behavior;

  const NeuroQuestionSet({
    required this.autism,
    required this.adhd,
    required this.behavior,
  });
}

class _Band {
  final int min;
  final int max;
  final NeuroQuestionSet set;

  const _Band(this.min, this.max, this.set);

  bool contains(int ageMonths) => ageMonths >= min && ageMonths <= max;
}

class NeuroBehavioralQuestionBank {
  static NeuroQuestionSet forAgeMonths(int ageMonths) {
    for (final band in _bands) {
      if (band.contains(ageMonths)) return band.set;
    }
    return _bands.last.set;
  }

  static NeuroQuestion q(String text, int weight) => NeuroQuestion(text: text, weight: weight);

  static NeuroQuestionSet _set({
    required List<NeuroQuestion> aut,
    required List<NeuroQuestion> adhd,
    required List<NeuroQuestion> beh,
  }) {
    return NeuroQuestionSet(autism: aut, adhd: adhd, behavior: beh);
  }

  static final List<_Band> _bands = [
    _Band(0, 3, _set(
      aut: [
        q('Looks at caregiver\'s face while feeding?', 3),
        q('Responds to caregiver\'s voice?', 3),
        q('Smiles back when smiled at?', 4),
        q('Makes small cooing sounds?', 2),
        q('Calms when comforted?', 3),
      ],
      adhd: [
        q('Stays calm for short periods?', 2),
        q('Focuses on face for a few seconds?', 3),
        q('Settles after feeding?', 2),
        q('Sleeps adequately for age?', 2),
        q('Responds to gentle soothing?', 3),
      ],
      beh: [
        q('Shows comfort with familiar caregiver?', 3),
        q('Reacts differently to hunger/discomfort?', 2),
        q('Appears relaxed most times?', 2),
        q('Responds when picked up?', 3),
        q('Shows early bonding signs?', 4),
      ],
    )),
    _Band(4, 6, _set(
      aut: [
        q('Enjoys playful interaction?', 3),
        q('Responds to name occasionally?', 3),
        q('Laughs aloud?', 2),
        q('Looks at caregiver during play?', 3),
        q('Shows interest in people?', 4),
      ],
      adhd: [
        q('Engages with toy briefly?', 3),
        q('Follows moving object?', 3),
        q('Responds when spoken to?', 2),
        q('Settles after excitement?', 3),
        q('Shows controlled body movement?', 4),
      ],
      beh: [
        q('Expresses emotions clearly?', 2),
        q('Calms with familiar adult?', 3),
        q('Enjoys routine interaction?', 2),
        q('Shows curiosity safely?', 3),
        q('Adapts to feeding/sleep routine?', 3),
      ],
    )),
    _Band(7, 9, _set(
      aut: [
        q('Responds consistently to name?', 4),
        q('Makes eye contact during play?', 4),
        q('Enjoys social games?', 3),
        q('Uses sounds to get attention?', 3),
        q('Shares enjoyment with caregiver?', 4),
      ],
      adhd: [
        q('Plays with one toy for 2-3 minutes?', 3),
        q('Follows simple "no" tone?', 3),
        q('Calms after excitement?', 3),
        q('Shows controlled sitting/crawling?', 4),
        q('Stays engaged in activity briefly?', 3),
      ],
      beh: [
        q('Shows stranger awareness?', 2),
        q('Seeks comfort when upset?', 3),
        q('Expresses different emotions?', 3),
        q('Shows attachment preference?', 4),
        q('Follows simple routine?', 3),
      ],
    )),
    _Band(10, 12, _set(
      aut: [
        q('Points to show interest?', 5),
        q('Imitates gestures?', 4),
        q('Responds when called?', 4),
        q('Shares toys with caregiver?', 3),
        q('Enjoys interactive play?', 4),
      ],
      adhd: [
        q('Sits and focuses on toy?', 3),
        q('Follows simple instruction?', 4),
        q('Waits briefly before grabbing?', 4),
        q('Shows controlled movement?', 3),
        q('Calms with reassurance?', 3),
      ],
      beh: [
        q('Expresses frustration appropriately?', 3),
        q('Responds to limits?', 3),
        q('Shows affection?', 3),
        q('Adjusts slowly to new place?', 4),
        q('Participates in routine activities?', 3),
      ],
    )),
    _Band(13, 18, _set(
      aut: [
        q('Uses meaningful simple words?', 4),
        q('Points to request?', 5),
        q('Brings object to show?', 5),
        q('Responds to name consistently?', 4),
        q('Enjoys playing with people?', 3),
      ],
      adhd: [
        q('Focuses on task for few minutes?', 4),
        q('Follows 1-step instruction?', 4),
        q('Sits during feeding?', 3),
        q('Controls climbing safely?', 3),
        q('Calms after excitement?', 3),
      ],
      beh: [
        q('Shows affection?', 2),
        q('Expresses emotions clearly?', 3),
        q('Follows simple rule?', 3),
        q('Adapts to routine?', 3),
        q('Shows interest in peers?', 4),
      ],
    )),
    _Band(19, 24, _set(
      aut: [
        q('Speaks 10+ words?', 4),
        q('Combines two words?', 5),
        q('Shows pretend play?', 5),
        q('Makes eye contact while speaking?', 4),
        q('Shares interest with caregiver?', 4),
      ],
      adhd: [
        q('Focuses on play 3-5 minutes?', 4),
        q('Waits briefly when asked?', 4),
        q('Follows 2-step instruction?', 5),
        q('Controls impulsive grabbing?', 4),
        q('Sits during short story time?', 4),
      ],
      beh: [
        q('Plays beside other children?', 2),
        q('Expresses feelings with words?', 4),
        q('Follows simple rules?', 3),
        q('Manages mild frustration?', 4),
        q('Responds to routine changes?', 4),
      ],
    )),
    _Band(25, 27, _set(
      aut: [
        q('Uses 2-3 word sentences?', 4),
        q('Points to show things?', 5),
        q('Looks at you while talking?', 4),
        q('Enjoys pretend play?', 5),
        q('Responds to name?', 4),
      ],
      adhd: [
        q('Sits 3-5 minutes in activity?', 4),
        q('Follows 2-step instructions?', 5),
        q('Finishes small tasks?', 4),
        q('Waits briefly before acting?', 4),
        q('Stays near caregiver outside?', 3),
      ],
      beh: [
        q('Plays beside peers?', 2),
        q('Expresses feelings verbally?', 4),
        q('Responds to simple rules?', 3),
        q('Calms with help?', 3),
        q('Follows daily routine?', 4),
      ],
    )),
    _Band(28, 30, _set(
      aut: [
        q('Speaks short clear sentences?', 4),
        q('Answers simple questions?', 4),
        q('Maintains eye contact?', 4),
        q('Shows interest in peers?', 4),
        q('Shares enjoyment?', 4),
      ],
      adhd: [
        q('Focuses 5 minutes on toy?', 4),
        q('Listens when spoken to?', 3),
        q('Follows instructions consistently?', 5),
        q('Controls unsafe climbing?', 4),
        q('Returns when called?', 4),
      ],
      beh: [
        q('Takes turns briefly?', 4),
        q('Accepts limits?', 3),
        q('Expresses frustration verbally?', 4),
        q('Adjusts to routine change?', 4),
        q('Cooperates with adults?', 4),
      ],
    )),
    _Band(31, 33, _set(
      aut: [
        q('Uses 3-4 word sentences?', 4),
        q('Asks simple questions?', 4),
        q('Enjoys peer play?', 4),
        q('Copies adult actions?', 3),
        q('Understands simple emotions?', 4),
      ],
      adhd: [
        q('Completes 5-minute activity?', 4),
        q('Follows instruction without repeat?', 5),
        q('Waits for short turn?', 4),
        q('Controls running indoors?', 4),
        q('Transitions between tasks?', 4),
      ],
      beh: [
        q('Shares toys?', 4),
        q('Calms after upset?', 3),
        q('Follows safety rules?', 4),
        q('Responds to praise?', 3),
        q('Expresses needs clearly?', 4),
      ],
    )),
    _Band(34, 36, _set(
      aut: [
        q('Speaks clearly in small sentences?', 4),
        q('Answers "why/where" questions?', 5),
        q('Maintains eye contact in conversation?', 4),
        q('Enjoys group play?', 4),
        q('Shows imaginative play?', 5),
      ],
      adhd: [
        q('Sits 5-7 minutes structured activity?', 4),
        q('Completes simple tasks independently?', 5),
        q('Waits for turn?', 4),
        q('Follows 2-3 step instructions?', 5),
        q('Controls impulsive actions?', 4),
      ],
      beh: [
        q('Follows home rules?', 3),
        q('Expresses emotions appropriately?', 4),
        q('Cooperates in group play?', 4),
        q('Adjusts to new environment?', 4),
        q('Recovers after frustration?', 4),
      ],
    )),
    _Band(37, 42, _set(
      aut: [
        q('Speaks in clear 3-4 word sentences?', 4),
        q('Answers simple "what" questions?', 4),
        q('Maintains eye contact during conversation?', 4),
        q('Enjoys playing with other children?', 4),
        q('Shows imaginative pretend play?', 5),
      ],
      adhd: [
        q('Sits for 5-7 minutes during activity?', 4),
        q('Follows 2-3 step instructions?', 5),
        q('Waits briefly for turn?', 4),
        q('Completes simple task independently?', 5),
        q('Controls excessive running indoors?', 4),
      ],
      beh: [
        q('Follows simple house rules?', 3),
        q('Expresses feelings using words?', 4),
        q('Cooperates during group play?', 4),
        q('Calms down after frustration?', 4),
        q('Adjusts to small routine changes?', 4),
      ],
    )),
    _Band(43, 48, _set(
      aut: [
        q('Speaks in full sentences clearly?', 4),
        q('Answers simple "why" questions?', 5),
        q('Understands basic emotions of others?', 5),
        q('Plays cooperatively with peers?', 5),
        q('Maintains back-and-forth conversation?', 5),
      ],
      adhd: [
        q('Sits for 8-10 minutes activity?', 5),
        q('Completes assigned activity?', 5),
        q('Follows classroom-style instruction?', 5),
        q('Waits patiently in short queue?', 4),
        q('Controls impulsive grabbing?', 4),
      ],
      beh: [
        q('Shares toys without constant reminder?', 4),
        q('Accepts correction calmly?', 4),
        q('Manages mild anger verbally?', 5),
        q('Follows daily routine independently?', 4),
        q('Shows empathy toward others?', 5),
      ],
    )),
    _Band(49, 54, _set(
      aut: [
        q('Maintains conversation for several exchanges?', 5),
        q('Understands social rules (greeting, turn-taking)?', 5),
        q('Uses imaginative stories in play?', 5),
        q('Understands facial expressions?', 5),
        q('Makes friends and seeks peer interaction?', 5),
      ],
      adhd: [
        q('Focuses on activity 10-12 minutes?', 5),
        q('Follows multi-step instructions?', 6),
        q('Completes task before switching?', 5),
        q('Waits without interrupting frequently?', 5),
        q('Sits appropriately in group setting?', 5),
      ],
      beh: [
        q('Follows classroom rules?', 4),
        q('Manages frustration independently?', 5),
        q('Cooperates in team activity?', 5),
        q('Uses polite words regularly?', 4),
        q('Accepts losing in games?', 5),
      ],
    )),
    _Band(55, 60, _set(
      aut: [
        q('Engages in meaningful conversation?', 5),
        q('Understands jokes or simple humor?', 6),
        q('Interprets others\' emotions correctly?', 6),
        q('Participates actively in group play?', 5),
        q('Adapts to new social situations?', 6),
      ],
      adhd: [
        q('Focuses 12-15 minutes on structured task?', 6),
        q('Completes homework-like activity?', 6),
        q('Follows 3-step instructions independently?', 6),
        q('Waits calmly for turn?', 5),
        q('Controls body movements in class setting?', 5),
      ],
      beh: [
        q('Resolves small peer conflicts verbally?', 6),
        q('Follows rules without reminders?', 5),
        q('Shows responsibility for belongings?', 5),
        q('Manages anger safely?', 5),
        q('Demonstrates empathy consistently?', 6),
      ],
    )),
    _Band(61, 66, _set(
      aut: [
        q('Holds back-and-forth conversation naturally?', 6),
        q('Understands sarcasm/simple figurative speech?', 6),
        q('Maintains friendships?', 6),
        q('Adjusts behavior based on social situation?', 6),
        q('Shows flexible thinking during play?', 6),
      ],
      adhd: [
        q('Focuses 15-18 minutes task?', 6),
        q('Completes assigned work independently?', 6),
        q('Waits patiently in group activities?', 6),
        q('Avoids interrupting others?', 5),
        q('Controls impulsive behavior consistently?', 6),
      ],
      beh: [
        q('Follows school rules independently?', 5),
        q('Handles frustration calmly?', 6),
        q('Cooperates in team projects?', 6),
        q('Accepts feedback positively?', 5),
        q('Shows emotional self-control?', 6),
      ],
    )),
    _Band(67, 72, _set(
      aut: [
        q('Maintains detailed conversation?', 6),
        q('Understands others\' perspectives?', 6),
        q('Participates confidently in group discussions?', 6),
        q('Adjusts behavior in different social settings?', 6),
        q('Demonstrates imaginative and flexible thinking?', 6),
      ],
      adhd: [
        q('Focuses 20 minutes on structured task?', 6),
        q('Completes schoolwork without supervision?', 6),
        q('Follows multi-step classroom instructions?', 6),
        q('Waits turn patiently in all settings?', 6),
        q('Controls body and impulses appropriately?', 6),
      ],
      beh: [
        q('Resolves conflicts independently?', 6),
        q('Shows consistent emotional regulation?', 6),
        q('Demonstrates responsibility daily?', 6),
        q('Respects rules in different environments?', 6),
        q('Maintains positive peer relationships?', 6),
      ],
    )),
  ];
}
