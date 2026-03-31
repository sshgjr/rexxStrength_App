import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OneRMPage extends StatefulWidget {
  const OneRMPage({super.key});

  @override
  State<OneRMPage> createState() => _OneRMPageState();
}

class _OneRMPageState extends State<OneRMPage> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();

  double? estimatedOneRM;
  List<Map<String, dynamic>> rmTable = [];

  static const Color primary = Color(0xFF16A34A);
  static const Color bg = Color(0xFF0B0F0C);
  static const Color card = Color(0xFF0F1612);
  static const Color textMain = Color(0xFFE9F5EF);
  static const Color textSub = Color(0xFFA7B9B0);

  // 1RM 기준 RM 비율
  final List<double> rmPercentages = const [
    1.000, // 1RM
    0.972, // 2RM
    0.945, // 3RM
    0.917, // 4RM
    0.889, // 5RM
    0.861, // 6RM
    0.833, // 7RM
    0.806, // 8RM
    0.778, // 9RM
    0.750, // 10RM
  ];

  double calculate1RM(double weight, int reps) {
    if (reps <= 1) return weight;
    return weight * (1 + reps / 30);
  }

  void handleCalculate() {
  FocusScope.of(context).unfocus();

  final weight = double.tryParse(weightController.text);
  final reps = int.tryParse(repsController.text);

  if (weight == null || reps == null || weight <= 0 || reps <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('무게와 반복 횟수를 올바르게 입력해주세요.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  // 입력한 reps에 해당하는 RM 퍼센트로 1RM 역산
  final double oneRM;
  if (reps >= 1 && reps <= 10) {
    oneRM = weight / rmPercentages[reps - 1];
  } else {
    // 10RM 초과 시 Epley 공식으로 계산
    oneRM = weight * (1 + reps / 30);
  }

  final table = List.generate(10, (index) {
    final rm = index + 1;
    final percent = rmPercentages[index];
    // 입력한 reps와 동일한 RM이면 입력 무게 그대로 표시
    final estimatedWeight = (rm == reps) ? weight : oneRM * percent;

    return {'rm': rm, 'percent': percent * 100, 'weight': estimatedWeight};
  });

  setState(() {
    estimatedOneRM = oneRM;
    rmTable = table;
  });
}

  @override
  void dispose() {
    weightController.dispose();
    repsController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: textMain,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildResultTable() {
    if (rmTable.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              const Text(
                '예상 1RM',
                style: TextStyle(
                  color: textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${estimatedOneRM!.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rmTable.length; i++) ...[
                _buildRmRow(
                  rm: rmTable[i]['rm'] as int,
                  percent: rmTable[i]['percent'] as double,
                  weight: rmTable[i]['weight'] as double,
                  isHighlight: i == 0,
                ),
                if (i != rmTable.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withOpacity(0.05),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRmRow({
    required int rm,
    required double percent,
    required double weight,
    bool isHighlight = false,
  }) {
    final rowColor = isHighlight
        ? primary.withOpacity(0.14)
        : Colors.transparent;
    final labelColor = isHighlight ? primary : textMain;
    final percentColor = isHighlight ? const Color(0xFF7DFFAB) : textSub;
    final weightColor = isHighlight ? primary : textMain;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: isHighlight
            ? const BorderRadius.vertical(top: Radius.circular(18))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$rm RM',
              style: TextStyle(
                color: labelColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${percent.toStringAsFixed(rm == 1 ? 0 : 1)}%',
              style: TextStyle(
                color: percentColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${weight.toStringAsFixed(1)}kg',
            style: TextStyle(
              color: weightColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            '1RM 계산기',
            style: TextStyle(
              color: textMain,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: textMain),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.10),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '1RM 계산',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMain,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '무게와 반복 횟수를 입력하면\n1RM부터 10RM까지 한 번에 계산해줍니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSub,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInputField(
                        controller: weightController,
                        hintText: '무게 (kg)',
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: repsController,
                        hintText: '반복 횟수',
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: handleCalculate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '계산하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildResultTable(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
