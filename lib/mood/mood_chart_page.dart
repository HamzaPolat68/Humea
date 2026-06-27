import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:equatable/equatable.dart';

class MoodChartPage extends StatefulWidget {
  final List<FlSpot> userWeeklySpots;
  final List<FlSpot> userMonthlySpots;
  final List<FlSpot> userAllTimeSpots;

  final List<int> rawWeeklyScores;
  final List<int> rawMonthlyScores;
  final Map<int, List<int>> rawAllTimeScoresMap;

  final String currentPeriodLabel;
  final Function(int direction) onPeriodChanged;
  final Function(int periodIndex) onPeriodTabChanged;

  const MoodChartPage({
    super.key,
    required this.userWeeklySpots,
    required this.userMonthlySpots,
    required this.userAllTimeSpots,
    required this.rawWeeklyScores,
    required this.rawMonthlyScores,
    required this.rawAllTimeScoresMap,
    required this.currentPeriodLabel,
    required this.onPeriodChanged,
    required this.onPeriodTabChanged,
  });

  @override
  State<MoodChartPage> createState() => _MoodChartPageState();
}

class _MoodChartPageState extends State<MoodChartPage> {
  int _selectedPeriod = 0; // 0: Hafta, 1: Ay, 2: Tüm Zamanlar

  final Map<int, String> _scoreToEmoji = {
    5: "😍",
    4: "🙂",
    3: "😞",
    2: "😡",
    1: "💤",
  };

  @override
  Widget build(BuildContext context) {
    // Veri seçimi
    List<FlSpot> currentSpots;
    List<int> currentRawScores;

    if (_selectedPeriod == 0) {
      currentSpots = widget.userWeeklySpots;
      currentRawScores = widget.rawWeeklyScores;
    } else if (_selectedPeriod == 1) {
      currentSpots = widget.userMonthlySpots;
      currentRawScores = widget.rawMonthlyScores;
    } else {
      currentSpots = widget.userAllTimeSpots;
      currentRawScores = widget.rawAllTimeScoresMap.values
          .expand((x) => x)
          .toList();
    }

    // Ortalama ve Emoji hesaplama
    double avgScore = currentRawScores.isEmpty
        ? 0.0
        : currentRawScores.reduce((a, b) => a + b) / currentRawScores.length;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 179, 206, 235),
      appBar: AppBar(
        title: const Text(
          'Duygu Grafiği',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 15),
            if (_selectedPeriod != 2) _buildNavigationRow(),
            const SizedBox(height: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 25, 20, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      spreadRadius: 5,
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: currentSpots.isEmpty
                    ? const Center(
                        child: Text("Bu döneme ait veri bulunamadı."),
                      )
                    : LineChart(_mainChartDataWithSpots(currentSpots)),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    "Ortalama Skor",
                    currentRawScores.isEmpty
                        ? "-/5.0"
                        : "${avgScore.toStringAsFixed(1)}/5.0",
                    trailing: const Icon(
                      Icons.insights,
                      color: Colors.amber,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildSummaryCard(
                    "En Sık Duygu",
                    currentRawScores.isEmpty
                        ? "-"
                        : _scoreToText(_findModeOfList(currentRawScores)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final labels = ['Hafta', 'Ay', 'Tüm Zamanlar'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 5,
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(labels.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = index;
                });
                widget.onPeriodTabChanged(index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF42A5F5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationRow() {
    return Row(
      children: [
        IconButton(
          onPressed: () => widget.onPeriodChanged(-1),
          icon: const Icon(Icons.arrow_back_ios, size: 18),
        ),
        Expanded(
          child: Text(
            widget.currentPeriodLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => widget.onPeriodChanged(1),
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      ],
    );
  }

  // --- Yardımcı Metotlar ---

  LineChartData _mainChartDataWithSpots(List<FlSpot> spots) {
    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 1,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: _selectedPeriod == 0 ? 6 : (_selectedPeriod == 1 ? 3 : 11),
      minY: 0.5,
      maxY: 5.5,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: const Color(0xFF42A5F5),
          barWidth: 4,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, p, b, i) =>
                _EmojiDotPainter(score: spot.y.round()),
          ),
        ),
      ],
    );
  }

  int _findModeOfList(List<int> scores) {
    final freq = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (int s in scores) freq[s.clamp(1, 5)] = freq[s.clamp(1, 5)]! + 1;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _scoreToText(int score) => [
    "💤 Yorgun",
    "😡 Sinirli",
    "😞 Hüzünlü",
    "🙂 İyi",
    "😍 Harika",
  ][score - 1];

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    int index = value.toInt();
    String text = _selectedPeriod == 0
        ? ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][index % 7]
        : _selectedPeriod == 1
        ? ['1.Hf', '2.Hf', '3.Hf', '4.Hf'][index % 4]
        : [
            'Oca',
            'Şub',
            'Mar',
            'Nis',
            'May',
            'Haz',
            'Tem',
            'Ağu',
            'Eyl',
            'Eki',
            'Kas',
            'Ara',
          ][index % 12];
    return SideTitleWidget(
      meta: meta,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiDotPainter extends FlDotPainter with EquatableMixin {
  final int score;

  _EmojiDotPainter({required this.score});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offset) {
    String emoji = "🙂";
    switch (score.clamp(1, 5)) {
      case 5:
        emoji = "😍";
        break;
      case 4:
        emoji = "🙂";
        break;
      case 3:
        emoji = "😞";
        break;
      case 2:
        emoji = "😡";
        break;
      case 1:
        emoji = "💤";
        break;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final double xCenter = offset.dx - (textPainter.width / 2);
    final double yCenter = offset.dy - (textPainter.height / 1.1);
    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  @override
  Size getSize(FlSpot spot) => const Size(32, 32);

  @override
  Color get mainColor => Colors.transparent;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is _EmojiDotPainter && b is _EmojiDotPainter) {
      return _EmojiDotPainter(
        score: (a.score + (b.score - a.score) * t).round(),
      );
    }
    return b;
  }

  @override
  List<Object?> get props => [score];
}
