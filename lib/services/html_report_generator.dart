/// Service responsible for generating prompts for AI analysis and assembling the final HTML report.
class HtmlReportGenerator {
  // --- Constants for Prompts ---

  static const String _baseInstructions = '''
You are an AI assistant helping to analyze medical record data.
Focus ONLY on the provided data. Do NOT invent information.
Do NOT provide medical advice or diagnoses.
Generate ONLY the requested HTML fragment. Do NOT include `<html>`, `<head>`, `<body>`, or `<style>` tags in your response for this specific task.
Use standard HTML tags like `<h2>`, `<p>`, `<ul>`, `<li>`.
''';

  static const String _cssStyles = '''
body {
  font-family: Verdana, sans-serif; /* Use Verdana font */
  padding: 40px; /* Increased padding */
  line-height: 1.6; /* Improve readability */
  background-color: #f8f9fa; /* Light background */
}
h1, h2 {
  color: #343a40; /* Darker heading color */
  border-bottom: 1px solid #dee2e6; /* Subtle separator */
  padding-bottom: 5px;
  margin-top: 20px;
}
h1 { font-size: 24px; }
h2 { font-size: 20px; }
ul { padding-left: 20px; }
li { margin-bottom: 8px; }
p { margin-bottom: 12px; }
.report-section { margin-bottom: 30px; } /* Add space between sections */
''';

  // --- Prompt Generation Methods ---

  /// Generates the prompt for the "Current Health Situation" section.
  static String generateCurrentSituationPrompt(String latestRecordData) {
    return '''
$_baseInstructions

Task: Analyze the LATEST medical record provided below and generate an HTML fragment summarizing the current health situation.

The HTML fragment MUST:
1. Start with an `<h2>` tag containing "Current Health Situation".
2. Be followed by a paragraph (`<p>`) summarizing the key findings from THIS specific record (e.g., main points from the summary, notable lab results compared to reference ranges).

Latest Record Data:
---
$latestRecordData
---

Remember: Generate ONLY the HTML fragment for this section (starting with `<h2>`).
''';
  }

  /// Generates the prompt for the "Detailed Observations" (Trends) section.
  static String generateTrendsPrompt(String allConsolidatedData) {
    return '''
$_baseInstructions

Task: Analyze ALL the consolidated medical records provided below and generate an HTML fragment detailing significant trends, patterns, or notable changes over time.

The HTML fragment MUST:
1. Start with an `<h2>` tag containing "Detailed Observations (Trends)".
2. Be followed by an unordered list (`<ul>`) detailing observations.
3. Each list item (`<li>`) should describe a specific trend, pattern, or significant change observed across the records (e.g., changes in specific lab values over time, recurring themes in summaries, comparison of recent results to older ones). Focus on changes relative to reference ranges.

Consolidated Data (All Records):
---
$allConsolidatedData
---

Remember: Generate ONLY the HTML fragment for this section (starting with `<h2>`).
''';
  }

  // --- HTML Assembly Method ---

  /// Assembles the final HTML report from the generated fragments.
  static String generateFullHtmlReport(
    String currentSituationHtml,
    String trendsHtml,
  ) {
    // Basic validation/fallback for fragments
    final situationContent =
        (currentSituationHtml.isNotEmpty)
            ? currentSituationHtml
            : '<h2>Current Health Situation</h2><p>Error: Analysis data not generated.</p>';
    final trendsContent =
        (trendsHtml.isNotEmpty)
            ? trendsHtml
            : '<h2>Detailed Observations (Trends)</h2><p>Error: Analysis data not generated.</p>';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Health Analysis Report</title>
    <style>
$_cssStyles
    </style>
</head>
<body>
    <h1>Health Analysis Report</h1>

    <div class="report-section">
      $situationContent
    </div>

    <div class="report-section">
      $trendsContent
    </div>

</body>
</html>
''';
  }
}
