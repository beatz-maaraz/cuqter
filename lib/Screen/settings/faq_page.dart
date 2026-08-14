import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = ["All", "General", "Appearance", "Storage", "Security"];

  final List<Map<String, String>> _faqItems = [
    {
      "category": "General",
      "question": "What is Cuqter Messenger?",
      "answer": "Cuqter is a secure, next-generation messaging platform designed with premium customizable themes, rich media sharing features, and smart AI capabilities."
    },
    {
      "category": "Appearance",
      "question": "How do I change the accent color of the application?",
      "answer": "Go to Settings > Appearance. You can choose from our curated color palette (Violet, Sky Blue, Emerald Green, Coral, etc.) to instantaneously update the whole app accent dynamically."
    },
    {
      "category": "Appearance",
      "question": "Can I change the home screen launcher icon?",
      "answer": "Yes! In Settings > Appearance, scroll to the App Icon section. You can select custom launcher styles such as Classic Violet, Stealth Midnight, or Sunset Glow, and preview them live in the Home Screen Mockup."
    },
    {
      "category": "Storage",
      "question": "How can I clear temporary cache files?",
      "answer": "Navigate to Settings > Storage & Data. In the total storage card, tap on 'Clear Temporary Cache' to delete non-essential cached media and log files. Tapping categories shows the size details."
    },
    {
      "category": "Security",
      "question": "Are my chat conversations secure?",
      "answer": "Absolutely! Cuqter routes messages through real-time encrypted data sync channels and provides lock options to prevent unauthorized access to your account."
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    return _faqItems.where((item) {
      final matchesCategory = _selectedCategory == "All" || item["category"] == _selectedCategory;
      final matchesSearch = item["question"]!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item["answer"]!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Column(
        children: [
          _buildSearchBar(colorScheme),
          _buildCategoryFilter(colorScheme),
          Expanded(
            child: _filteredFaqs.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _filteredFaqs.length,
                    itemBuilder: (context, index) {
                      final faq = _filteredFaqs[index];
                      return _buildFaqTile(faq, colorScheme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search answers, keywords...',
            hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
            prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = "";
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                cat,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.04),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFaqTile(Map<String, String> faq, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            faq["question"]!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(
              faq["answer"]!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedHelpCircle,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching FAQ found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or category filters',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
