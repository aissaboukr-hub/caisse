import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/sale_service.dart';
import '../../services/user_service.dart';

class SalesScreen extends StatefulWidget {
  final String cashierName;

  const SalesScreen({super.key, required this.cashierName});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final SaleService _saleService = SaleService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  bool _showCart = false; // Pour afficher/masquer le panier sur mobile

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _filteredProducts {
    return _productService.getProducts(
      category: _selectedCategory,
      search: _searchQuery,
    );
  }

  // =============================================
  //              AJOUTER AU PANIER
  // =============================================

  void _addToCart(ProductModel product) {
    if (product.stock <= 0) {
      _showSnackBar('❌ Produit en rupture de stock', isError: true);
      return;
    }
    if (_cartService.getQuantity(product.id) >= product.stock) {
      _showSnackBar('⚠️ Stock maximum atteint', isError: true);
      return;
    }

    _cartService.addProduct(product);
    _showSnackBar('✅ ${product.name} ajouté', isError: false);
  }

  // =============================================
  //           FINALISER LE PAIEMENT
  // =============================================

  void _showPaymentDialog() {
    if (_cartService.itemCount == 0) {
      _showSnackBar('🛒 Le panier est vide', isError: true);
      return;
    }

    final TextEditingController amountController = TextEditingController();
    String selectedPayment = 'cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final total = _cartService.totalAmount;
            final entered =
                double.tryParse(amountController.text) ?? 0;
            final change = entered - total;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- EN-TÊTE ----
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment,
                                color: Colors.indigo.shade700, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Paiement',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ---- RÉSUMÉ ----
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Articles:',
                                    style: TextStyle(
                                        color: Colors.grey.shade600)),
                                Text(
                                    '${_cartService.totalQuantity} article(s)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL À PAYER:',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  _cartService.formattedTotal,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ---- MODE DE PAIEMENT ----
                      Row(
                        children: [
                          _paymentMethodChip(
                              'cash', '💵 Espèces', selectedPayment, (v) {
                            setDialogState(() => selectedPayment = v);
                          }),
                          const SizedBox(width: 8),
                          _paymentMethodChip(
                              'mobile', '📱 Mobile', selectedPayment, (v) {
                            setDialogState(() => selectedPayment = v);
                          }),
                          const SizedBox(width: 8),
                          _paymentMethodChip(
                              'card', '💳 Carte', selectedPayment, (v) {
                            setDialogState(() => selectedPayment = v);
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ---- MONTANT REÇU ----
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Montant reçu (FC)',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.attach_money,
                              color: Colors.indigo.shade400),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Colors.indigo.shade400, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- MONNAIE À RENDRE ----
                      if (entered > 0)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: change >= 0
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: change >= 0
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                change >= 0
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: change >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                change >= 0
                                    ? 'Monnaie: ${change.toStringAsFixed(0)} FC'
                                    : 'Montant insuffisant: ${(total - entered).toStringAsFixed(0)} FC manquant',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: change >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ---- RACCOURCIS MONTANTS ----
                      if (selectedPayment == 'cash') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildQuickAmountButtons(
                              total, amountController, setDialogState),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ---- BOUTONS ----
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Text('Annuler',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: change >= 0 && entered > 0
                                  ? () {
                                      Navigator.pop(ctx);
                                      _processPayment(
                                          entered, selectedPayment);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 3,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 22),
                                  SizedBox(width: 8),
                                  Text('VALIDER',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildQuickAmountButtons(
    double total,
    TextEditingController controller,
    StateSetter setDialogState,
  ) {
    // Arrondir aux centaines supérieures
    final quickAmounts = <int>[];
    final rounded = ((total / 500).ceil() * 500).toInt();
    for (int i = 0; i < 4; i++) {
      quickAmounts.add(rounded + (i * 500));
    }
    // Ajouter des gros montants
    if (total > 5000) {
      quickAmounts.add(10000);
      quickAmounts.add(20000);
      quickAmounts.add(50000);
    }

    return quickAmounts.take(5).map((amount) {
      return GestureDetector(
        onTap: () {
          controller.text = amount.toString();
          setDialogState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Text(
            '$amount FC',
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _paymentMethodChip(
    String value,
    String label,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? Colors.indigo.shade600 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  //            TRAITEMENT DU PAIEMENT
  // =============================================

  Future<void> _processPayment(
      double amountPaid, String paymentMethod) async {
    // 1. Enregistrer la vente
    final sale = await _saleService.recordSale(
      cashierName: widget.cashierName,
      items: _cartService.items.toList(),
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
    );

    // 2. Diminuer les stocks
    for (final item in _cartService.items) {
      _productService.decreaseStock(item.product.id, item.quantity);
    }

    // 3. Vider le panier
    _cartService.clearCart();
    setState(() => _showCart = false);

    // 4. Afficher le reçu
    _showReceiptDialog(sale);
  }

  // =============================================
  //              REÇU DE VENTE
  // =============================================

  void _showReceiptDialog(dynamic sale) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- SUCCÈS ----
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check,
                    size: 40, color: Colors.green.shade700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vente Réussie !',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ---- DÉTAILS ----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _receiptRow('N° Vente', '#${sale.id.substring(6)}'),
                    _receiptRow('Caissier', sale.cashierName),
                    _receiptRow(
                        'Articles', '${sale.items.length} article(s)'),
                    const Divider(),
                    _receiptRow(
                      'TOTAL',
                      '${sale.totalAmount.toStringAsFixed(0)} FC',
                      isBold: true,
                    ),
                    _receiptRow('Payé',
                        '${sale.amountPaid.toStringAsFixed(0)} FC'),
                    _receiptRow('Monnaie',
                        '${sale.change.toStringAsFixed(0)} FC'),
                    _receiptRow('Mode', _paymentLabel(sale.paymentMethod)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- BOUTON OK ----
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('FERMER',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontSize: isBold ? 16 : 14,
                  color: isBold ? Colors.indigo.shade700 : Colors.black87)),
        ],
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
        return method;
    }
  }

  // =============================================
  //              SNACKBAR
  // =============================================

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // =============================================
  //               BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // ---- HEADER ----
          _buildHeader(),

          // ---- CONTENU PRINCIPAL ----
          Expanded(
            child: _showCart ? _buildCartView() : _buildProductGrid(),
          ),
        ],
      ),

      // ---- BARRE INFÉRIEURE DU PANIER ----
      bottomNavigationBar: _buildBottomCartBar(),
    );
  }

  // =============================================
  //              HEADER
  // =============================================

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        ),
      ),
      child: Column(
        children: [
          // Ligne 1 : Titre + infos
          Row(
            children: [
              const Icon(Icons.point_of_sale_rounded,
                  color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Point de Vente',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              // Badge du panier
              GestureDetector(
                onTap: () => setState(() => _showCart = !_showCart),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${_cartService.totalQuantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Info caissier
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      widget.cashierName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---- BARRE DE RECHERCHE ----
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withOpacity(0.7)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //           GRILLE DE PRODUITS
  // =============================================

  Widget _buildProductGrid() {
    return Column(
      children: [
        // ---- FILTRES CATÉGORIES ----
        _buildCategoryFilters(),

        // ---- LISTE DES PRODUITS ----
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 70, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucun produit trouvé',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(_filteredProducts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    final categories = _productService.categories;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo.shade600 : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? Colors.indigo.shade600
                      : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =============================================
  //           CARTE PRODUIT
  // =============================================

  Widget _buildProductCard(ProductModel product) {
    final inCart = _cartService.isInCart(product.id);
    final qty = _cartService.getQuantity(product.id);
    final lowStock = product.stock <= 5;

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: inCart
              ? Border.all(color: Colors.indigo.shade400, width: 2)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: inCart
                  ? Colors.indigo.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- EMOJI / ICÔNE ----
                  Center(
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: _categoryColor(product.category)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _categoryEmoji(product.category),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ---- NOM ----
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const Spacer(),

                  // ---- PRIX ----
                  Text(
                    '${product.price.toStringAsFixed(0)} FC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.indigo.shade700,
                    ),
                  ),

                  // ---- STOCK ----
                  Row(
                    children: [
                      Icon(
                        lowStock
                            ? Icons.warning_amber_rounded
                            : Icons.inventory_2_outlined,
                        size: 13,
                        color: lowStock
                            ? Colors.orange.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(
                          fontSize: 11,
                          color: lowStock
                              ? Colors.orange.shade600
                              : Colors.grey.shade400,
                          fontWeight:
                              lowStock ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- BADGE DANS LE PANIER ----
            if (inCart)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case 'Boissons':
        return '🥤';
      case 'Alimentation':
        return '🍞';
      case 'Hygiène':
        return '🧴';
      case 'Confiserie':
        return '🍬';
      default:
        return '📦';
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Boissons':
        return Colors.blue;
      case 'Alimentation':
        return Colors.orange;
      case 'Hygiène':
        return Colors.purple;
      case 'Confiserie':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // =============================================
  //           VUE PANIER
  // =============================================

  Widget _buildCartView() {
    if (_cartService.itemCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Le panier est vide',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Appuyez sur un produit pour l\'ajouter',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ---- EN-TÊTE PANIER ----
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('Mon Panier',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _cartService.clearCart();
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                label: Text('Vider',
                    style: TextStyle(color: Colors.red.shade600)),
              ),
            ],
          ),
        ),

        // ---- LISTE DES ARTICLES ----
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _cartService.items.length,
            itemBuilder: (context, index) {
              final item = _cartService.items[index];
              return _buildCartItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(_categoryEmoji(item.product.category),
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(item.formattedPrice,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),

          // Contrôles quantité
          _quantityControl(item),
          const SizedBox(width: 12),

          // Total
          Text(item.formattedTotal,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                  fontSize: 14)),

          // Supprimer
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.red.shade300),
            onPressed: () {
              _cartService.removeProduct(item.product.id);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _quantityControl(dynamic item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(
            icon: Icons.remove,
            onTap: () {
              _cartService.decreaseQuantity(item.product.id);
              setState(() {});
            },
          ),
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          _qtyButton(
            icon: Icons.add,
            onTap: () {
              _cartService.increaseQuantity(item.product.id);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.indigo.shade600),
      ),
    );
  }

  // =============================================
  //        BARRE INFÉRIEURE DU PANIER
  // =============================================

  Widget _buildBottomCartBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _cartService.itemCount == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '🛒 Appuyez sur un produit pour commencer',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14),
              ),
            )
          : Row(
              children: [
                // Info panier
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_cartService.totalQuantity} article(s)',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                      Text(
                        _cartService.formattedTotal,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bouton Payer
                ElevatedButton.icon(
                  onPressed: _showPaymentDialog,
                  icon: const Icon(Icons.payment_rounded, size: 22),
                  label: const Text(
                    'PAYER',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                ),
              ],
            ),
    );
  }
}