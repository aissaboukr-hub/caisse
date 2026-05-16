import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/sale_model.dart';
import '../../services/sale_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String userRole;

  const SalesHistoryScreen({
    super.key,
    this.userRole = 'admin',
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final SaleService _saleService = SaleService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'all';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =============================================
  //        FILTRER LES VENTES
  // =============================================

  List<SaleModel> get _filteredSales {
    var sales = _saleService.sales;

    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'today':
        sales = _saleService.getSalesByDate(now);
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        sales = _saleService.getSalesByDateRange(weekAgo, now);
        break;
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        sales = _saleService.getSalesByDateRange(monthAgo, now);
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          sales = _saleService.getSalesByDateRange(
              _customStartDate!, _customEndDate!);
        }
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      sales = sales.where((s) {
        return s.id.toLowerCase().contains(q) ||
            s.cashierName.toLowerCase().contains(q) ||
            s.formattedDate.contains(q) ||
            s.items.any(
                (item) => item.product.name.toLowerCase().contains(q));
      }).toList();
    }

    return sales;
  }

  // =============================================
  //        STATISTIQUES DE LA PÉRIODE
  // =============================================

  Map<String, dynamic> get _periodStats {
    final sales = _filteredSales;
    final totalRevenue =
        sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalItems =
        sales.fold(0, (sum, s) => sum + s.totalItems);
    final avgTicket =
        sales.isEmpty ? 0.0 : totalRevenue / sales.length;

    return {
      'count': sales.length,
      'revenue': totalRevenue,
      'items': totalItems,
      'average': avgTicket,
    };
  }

  // =============================================
  //        SÉLECTIONNER UNE DATE
  // =============================================

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customStartDate != null
          ? DateTimeRange(
              start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedFilter = 'custom';
      });
    }
  }

  // =============================================
  //     CONFIRMER SUPPRESSION (ADMIN SEULEMENT)
  // =============================================

  void _confirmDeleteSale(SaleModel sale) {
    if (!_isAdmin) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber,
                color: Colors.red.shade400),
            const SizedBox(width: 10),
            const Text('Supprimer la vente'),
          ],
        ),
        content: Text(
          'Voulez-vous supprimer le ticket #${sale.id.substring(sale.id.length - 6)} ?\n'
          'Montant: ${sale.totalAmount.toStringAsFixed(0)} DZ\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              _saleService.deleteSale(sale.id);
              Navigator.pop(ctx);
              setState(() {});
              _showSnackBar('🗑️ Vente supprimée', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // =============================================
  //               BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    final filteredSales = _filteredSales;
    final stats = _periodStats;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        title: Text(
          _isAdmin ? 'Historique des Ventes' : 'Mes Ventes',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 19),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isAdmin && _saleService.totalSales > 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                if (value == 'clear') {
                  _confirmClearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep,
                          color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Vider l\'historique',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),

      body: Column(
        children: [
          _buildStatsHeader(stats),
          _buildSearchBar(),
          _buildFilterChips(),
          const SizedBox(height: 8),
          Expanded(
            child: filteredSales.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredSales.length,
                    itemBuilder: (context, index) {
                      return _buildSaleCard(filteredSales[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //           HEADER STATISTIQUES
  // =============================================

  Widget _buildStatsHeader(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            'Ventes', '${stats['count']}', Icons.receipt_long),
          _buildStatItem(
            'Chiffre', _formatAmount(stats['revenue'] as double),
            Icons.payments_outlined),
          _buildStatItem(
            'Articles', '${stats['items']}',
            Icons.inventory_2_outlined),
          _buildStatItem(
            'Moyenne', _formatAmount(stats['average'] as double),
            Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // =============================================
  //            BARRE DE RECHERCHE
  // =============================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher (ticket, caissier, article)...',
          hintStyle: TextStyle(
              color: Colors.grey.shade400, fontSize: 14),
          prefixIcon:
              Icon(Icons.search, color: Colors.indigo.shade300),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // =============================================
  //          FILTRES PAR PÉRIODE
  // =============================================

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('all', 'Tout', Icons.all_inclusive),
          const SizedBox(width: 8),
          _filterChip(
              'today', 'Aujourd\'hui', Icons.today),
          const SizedBox(width: 8),
          _filterChip('week', '7 jours', Icons.date_range),
          const SizedBox(width: 8),
          _filterChip(
              'month', '30 jours', Icons.calendar_month),
          const SizedBox(width: 8),
          _customDateChip(),
        ],
      ),
    );
  }

  Widget _filterChip(
      String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.indigo.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? Colors.indigo.shade600
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customDateChip() {
    final isSelected = _selectedFilter == 'custom';
    return GestureDetector(
      onTap: _pickCustomDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.indigo.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? Colors.indigo.shade600
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_calendar,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              _selectedFilter == 'custom' &&
                      _customStartDate != null
                  ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                  : 'Personnalisé',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  //           CARTE D'UNE VENTE
  // =============================================

  Widget _buildSaleCard(SaleModel sale) {
    return GestureDetector(
      onTap: () => _showTicketDetails(sale),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.shade400,
                      Colors.indigo.shade600
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.receipt_long,
                      color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${sale.id.substring(sale.id.length - 6)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time,
                            size: 13,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          sale.formattedTime,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          sale.cashierName,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.shopping_bag_outlined,
                            size: 14,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${sale.totalItems} article(s)',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 13,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          sale.formattedDate,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            _paymentLabel(sale.paymentMethod),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${sale.totalAmount.toStringAsFixed(0)} DZ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey.shade300),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return '💵 Espèces';
      case 'mobile':
        return '📱 Mobile';
      case 'card':
        return '💳 Carte';
      default:
        return '💵 Espèces';
    }
  }

  // =============================================
  //     DÉTAILS DU TICKET (NOM COMPLET)
  // =============================================

  void _showTicketDetails(SaleModel sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // POIGNÉE
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // CONTENU SCROLLABLE
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // EN-TÊTE
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.shade700,
                                Colors.indigo.shade500
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long,
                                  color: Colors.white,
                                  size: 40),
                              const SizedBox(height: 10),
                              const Text(
                                'TICKET DE VENTE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _headerRow('N° Ticket',
                                        '#${sale.id.substring(sale.id.length - 6)}'),
                                    const SizedBox(height: 4),
                                    _headerRow(
                                        'Date',
                                        sale.formattedDateTime),
                                    const SizedBox(height: 4),
                                    _headerRow(
                                        'Caissier',
                                        sale.cashierName),
                                    const SizedBox(height: 4),
                                    _headerRow(
                                        'Paiement',
                                        _paymentLabel(
                                            sale.paymentMethod)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ARTICLES
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.list_alt,
                                      color:
                                          Colors.indigo.shade600,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Articles (${sale.items.length} lignes • ${sale.totalItems} articles)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Colors.indigo.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Titre compteur
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.list_alt,
                                        size: 18,
                                        color: Colors
                                            .indigo.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${sale.items.length} article(s) • ${sale.totalItems} pièce(s)',
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors
                                            .indigo.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ✅ TOUS LES ARTICLES (2 LIGNES)
                              ...List.generate(
                                  sale.items.length, (index) {
                                final item = sale.items[index];
                                final isEven = index % 2 == 0;

                                return Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isEven
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                    border: Border(
                                      bottom: BorderSide(
                                        color:
                                            Colors.grey.shade200,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // LIGNE 1 : NUMÉRO + QUANTITÉ + NOM
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            '${index + 1}.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold,
                                              color: Colors
                                                  .grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration:
                                                BoxDecoration(
                                              color: Colors
                                                  .indigo.shade600,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                            ),
                                            child: Text(
                                              'x${item.quantity}',
                                              style:
                                                  const TextStyle(
                                                color:
                                                    Colors.white,
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 10),
                                          Expanded(
                                            child: Text(
                                              item.product.name,
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(
                                                    0xFF2D3436),
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // LIGNE 2 : P.U. + MONTANT
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                left: 22),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              'P.U: ${item.product.price.toStringAsFixed(0)} DZ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors
                                                    .grey.shade500,
                                              ),
                                            ),
                                            Text(
                                              '${item.totalPrice.toStringAsFixed(0)} DZ',
                                              style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors
                                                    .indigo.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // RÉSUMÉ
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.indigo.shade100),
                          ),
                          child: Column(
                            children: [
                              _summaryRow('Nombre d\'articles',
                                  '${sale.totalItems}'),
                              _summaryRow('Nombre de lignes',
                                  '${sale.items.length}'),
                              Divider(
                                  color: Colors.indigo.shade200,
                                  height: 16),
                              _summaryRow(
                                  'TOTAL',
                                  '${sale.totalAmount.toStringAsFixed(0)} DZ',
                                  isBold: true),
                              _summaryRow('Montant payé',
                                  '${sale.amountPaid.toStringAsFixed(0)} DZ'),
                              _summaryRow('Monnaie rendue',
                                  '${sale.change.toStringAsFixed(0)} DZ'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ACTIONS
                        Row(
                          children: [
                            if (_isAdmin) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _confirmDeleteSale(sale);
                                  },
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red),
                                  label: Text('Supprimer',
                                      style: TextStyle(
                                          color: Colors
                                              .red.shade600)),
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              14),
                                    ),
                                    side: BorderSide(
                                        color:
                                            Colors.red.shade200),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: _isAdmin ? 2 : 1,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(ctx),
                                icon: const Icon(Icons.close,
                                    size: 18),
                                label: const Text('Fermer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.indigo.shade600,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _headerRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: isBold
                    ? Colors.indigo.shade800
                    : Colors.grey.shade600,
                fontSize: isBold ? 15 : 13,
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: isBold ? 18 : 14,
                color: isBold
                    ? Colors.indigo.shade800
                    : Colors.black87,
              )),
        ],
      ),
    );
  }

  // =============================================
  //     CONFIRMER VIDER TOUT (ADMIN)
  // =============================================

  void _confirmClearAll() {
    if (!_isAdmin) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep,
                color: Colors.red.shade400),
            const SizedBox(width: 10),
            const Text('Vider l\'historique'),
          ],
        ),
        content: const Text(
          'Voulez-vous supprimer TOUT l\'historique ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              _saleService.clearAllSales();
              Navigator.pop(ctx);
              setState(() {});
              _showSnackBar('🗑️ Historique vidé',
                  isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }

  // =============================================
  //              ÉTAT VIDE
  // =============================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long,
                size: 45, color: Colors.indigo.shade200),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune vente enregistrée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Les ventes apparaîtront ici\naprès la première transaction'
                : 'Aucune vente pour cette période',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}