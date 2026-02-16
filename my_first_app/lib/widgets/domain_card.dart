import 'package:flutter/material.dart';
import 'question_card.dart';

class DomainCard extends StatefulWidget {
  final String domainKey; // e.g. 'LC'
  final String title;
  final List<String> questions;
  final Map<int,int> responses; // question index -> 1/0
  final ValueChanged<Map<int,int>> onChanged;
  final VoidCallback? onSave;
  final String saveLabel;
  final String yesLabel;
  final String noLabel;

  const DomainCard({
    super.key,
    required this.domainKey,
    required this.title,
    required this.questions,
    required this.responses,
    required this.onChanged,
    this.onSave,
    this.saveLabel = 'Save Topic',
    this.yesLabel = 'Yes',
    this.noLabel = 'No',
  });

  @override
  State<DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<DomainCard> {
  bool expanded = true;
  late Map<int,int> localResponses;

  @override
  void initState() {
    super.initState();
    localResponses = Map<int,int>.from(widget.responses);
  }

  void _updateResponse(int idx, int val) {
    setState(() => localResponses[idx] = val);
    widget.onChanged(localResponses);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFB1DAEF)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D4E89),
                          ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2A75B7), width: 1.6),
                    ),
                    child: Icon(
                      expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF2A75B7),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ...List.generate(widget.questions.length, (i) {
              final q = widget.questions[i];
              final val = localResponses.containsKey(i) ? localResponses[i] : null;
              return QuestionCard(
                question: q,
                value: val,
                onChanged: (v) => _updateResponse(i, v),
                yesLabel: widget.yesLabel,
                noLabel: widget.noLabel,
              );
            }),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F95EA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(widget.saveLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
