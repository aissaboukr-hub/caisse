import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/sale_service.dart';
import '../history/sales_history_screen.dart';
import 'barcode_scanner_screen.dart';

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
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  List<ProductModel> _searchResults = [];
  bool _showSearchResults = false;
  bool _isOpeningScanner = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // =============================================
  //        RECHERCHE DE PRODUITS (WILDCARD %)
  // =============================================

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isNotEmpty) {
        _searchResults =
            _productService.getProducts(search: query).take(15).toList();
        _showSearchResults = true;
      } else {
        _searchResults = [];
        _showSearchResults = false;
      }
    });
  }

  void _setSearchWithWildcard(String pattern) {
    _searchController.text = pattern;
    _onSearchChanged(pattern);
  }

  void _selectProduct(ProductModel product) {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _showSearchResults = false;
      _searchQuery = '';
    });
    _addToCart(product);
  }

  // =============================================
  //        HISTORIQUE DES VENTES (CAISSIER)
  // =============================================

  void _openSalesHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SalesHistoryScreen(
          userRole: 'caissier',
        ),
      ),
    );
  }

  // =============================================
  //        AJOUTER AU PANIER
  // =============================================

  void _addToCart(ProductModel product) {
    if (product.stock <= 0) {
      _showSnackBar(
          '❌ "${product.name}" est en rupture de stock',
          isError: true);
      return;
    }

    final currentQty = _cartService.getQuantity(product.id);
    if (currentQty >= product.stock) {
      _showSnackBar(
          '⚠️ Stock maximum atteint pour "${product.name}"',
          isError: true);
      return;
    }

    _cartService.addProduct(product);
    setState(() {});
    HapticFeedback.lightImpact();

    _showSnackBar('✅ ${product.name} ajouté', isError: false);
  }

  // =============================================
  //       DIALOG AJOUT MANUEL (QUANTITÉ)
  // =============================================

  void _showQuantityDialog(ProductModel product) {
    final TextEditingController qtyController =
        TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.add_shopping_cart,
                color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            const Expanded(
              child:
                  Text('Quantité', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('📦',
                      style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                            '${product.price.toStringAsFixed(0)} DZ',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              decoration: InputDecoration(
                labelText: 'Quantité',
                labelStyle:
                    TextStyle(color: Colors.grey.shade500),
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
            const SizedBox(height: 10),
            Text(
              'Stock disponible: ${product.stock}',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;
              if (qty > product.stock) {
                _showSnackBar('⚠️ Stock insuffisant',
                    isError: true);
                return;
              }
              Navigator.pop(ctx);
              for (int i = 0; i < qty; i++) {
                _cartService.addProduct(product);
              }
              setState(() {});
            },
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //     SCANNER CODE-BARRES
  // =============================================

  Future<void> _openScanner() async {
    if (_isOpeningScanner) return;
    _isOpeningScanner = true;

    _searchFocus.unfocus();
    setState(() => _showSearchResults = false);

    try {
      final String? scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(),
        ),
      );

      if (scannedCode != null && scannedCode.isNotEmpty) {
        _processScannedCode(scannedCode);
      }
    } catch (e) {
      debugPrint('Erreur scanner: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      _isOpeningScanner = false;
    }
  }

  void _processScannedCode(String code) {
    ProductModel? product = _productService.findByBarcode(code);

    product ??= _productService.products
        .where((p) => p.id == code)
        .firstOrNull;

    product ??=
        _productService.getProducts(search: code).firstOrNull;

    if (product != null) {
      _addToCart(product);
      _showSnackBar(
        '✅ "${product.name}" ajouté via scanner',
        isError: false,
      );
    } else {
      _showProductNotFoundDialog(code);
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.search_off,
                color: Colors.orange.shade600),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Produit introuvable',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Code: $barcode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun produit n\'est associé à ce code-barres.\n'
              'Voulez-vous le rechercher par nom ?',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ignorer',
                style:
                    TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _searchController.text = barcode;
              _onSearchChanged(barcode);
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Rechercher'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //       IMPRIMER / FINALISER LA VENTE
  // =============================================

  void _showPrintDialog() {
    if (_cartService.itemCount == 0) {
      _showSnackBar('🛒 Le panier est vide', isError: true);
      return;
    }

    final TextEditingController amountController =
        TextEditingController();

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
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.85,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ═══ EN-TÊTE ═══
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade700,
                            Colors.indigo.shade500
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long,
                              color: Colors.white, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'TICKET DE CAISSE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${_formatDate(DateTime.now())}',
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.8),
                                fontSize: 12),
                          ),
                          Text(
                            'Caissier: ${widget.cashierName}',
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.7),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_cartService.totalQuantity} article(s) • ${_cartService.itemCount} ligne(s)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══ ARTICLES SCROLLABLES ═══
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 0),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // En-tête tableau
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text('#',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors
                                                .indigo
                                                .shade700)),
                                  ),
                                  SizedBox(
                                    width: 35,
                                    child: Text('QTÉ',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors
                                                .indigo
                                                .shade700)),
                                  ),
                                  Expanded(
                                    child: Text('DÉSIGNATION',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors
                                                .indigo
                                                .shade700)),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text('P.U.',
                                        textAlign:
                                            TextAlign.right,
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors
                                                .indigo
                                                .shade700)),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('MONTANT',
                                        textAlign:
                                            TextAlign.right,
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors
                                                .indigo
                                                .shade700)),
                                  ),
                                ],
                              ),
                            ),

                            // TOUS LES ARTICLES
                            ...List.generate(
                                _cartService.items.length,
                                (index) {
                              final item =
                                  _cartService.items[index];
                              final isEven = index % 2 == 0;

                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
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
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors
                                              .grey.shade500,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 35,
                                      child: Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        decoration:
                                            BoxDecoration(
                                          color: Colors
                                              .indigo.shade600,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(4),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          textAlign:
                                              TextAlign.center,
                                          style:
                                              const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.product.name,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(
                                              0xFF2D3436),
                                        ),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        '${item.product.price.toStringAsFixed(0)}',
                                        textAlign:
                                            TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors
                                              .grey.shade600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '${item.totalPrice.toStringAsFixed(0)} DZ',
                                        textAlign:
                                            TextAlign.right,
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors
                                              .indigo.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 2),

                            // ═══ RÉSUMÉ ═══
                            Container(
                              margin:
                                  const EdgeInsets.only(top: 8),
                              padding:
                                  const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors
                                        .indigo.shade100),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(
                                        'Nombre d\'articles:',
                                        style: TextStyle(
                                          color: Colors
                                              .grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${_cartService.totalQuantity}',
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(
                                        'Nombre de lignes:',
                                        style: TextStyle(
                                          color: Colors
                                              .grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${_cartService.itemCount}',
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      color: Colors
                                          .indigo.shade200,
                                      height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL À PAYER:',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${_cartService.formattedTotal} DZ',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors
                                              .indigo.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ═══ MONTANT REÇU ═══
                            TextField(
                              controller: amountController,
                              keyboardType:
                                  TextInputType.number,
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly
                              ],
                              onChanged: (_) =>
                                  setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText:
                                    'Montant reçu (DZ)',
                                labelStyle: TextStyle(
                                    color:
                                        Colors.grey.shade600),
                                prefixIcon: Icon(
                                    Icons.payments_outlined,
                                    color: Colors
                                        .indigo.shade400),
                                filled: true,
                                fillColor: Colors.white,
                                enabledBorder:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                  borderSide: BorderSide(
                                      color: Colors
                                          .grey.shade300),
                                ),
                                focusedBorder:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                  borderSide: BorderSide(
                                      color: Colors
                                          .indigo.shade400,
                                      width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ═══ MONNAIE ═══
                            if (entered > 0)
                              Container(
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: change >= 0
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  border: Border.all(
                                    color: change >= 0
                                        ? Colors
                                            .green.shade200
                                        : Colors
                                            .red.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(
                                      change >= 0
                                          ? Icons
                                              .check_circle_outline
                                          : Icons
                                              .error_outline,
                                      color: change >= 0
                                          ? Colors
                                              .green.shade700
                                          : Colors
                                              .red.shade700,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      change >= 0
                                          ? 'Monnaie à rendre: ${change.toStringAsFixed(0)} DZ'
                                          : 'Manque: ${(total - entered).toStringAsFixed(0)} DZ',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: change >= 0
                                            ? Colors
                                                .green.shade700
                                            : Colors
                                                .red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ═══ RACCOURCIS MONTANTS ═══
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  _buildQuickAmountButtons(
                                      total,
                                      amountController,
                                      setDialogState),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ═══ BOUTONS FIXES ═══
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                          16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(ctx),
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
                                        Colors.grey.shade300),
                              ),
                              child: Text('Annuler',
                                  style: TextStyle(
                                      color:
                                          Colors.grey.shade600,
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed:
                                  change >= 0 && entered > 0
                                      ? () {
                                          Navigator.pop(ctx);
                                          _processSale(
                                              entered);
                                        }
                                      : null,
                              icon: const Icon(Icons.print,
                                  size: 22),
                              label: const Text(
                                'IMPRIMER',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.grey.shade300,
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    final quickAmounts = <int>[];
    final rounded = ((total / 500).ceil() * 500).toInt();
    for (int i = 0; i < 3; i++) {
      quickAmounts.add(rounded + (i * 500));
    }
    quickAmounts.add(10000);
    quickAmounts.add(20000);
    quickAmounts.add(50000);

    return quickAmounts.toSet().toList().take(6).map((amount) {
      return GestureDetector(
        onTap: () {
          controller.text = amount.toString();
          setDialogState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Text(
            '$amount DZ',
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

  // =============================================
  //         TRAITEMENT DE LA VENTE
  // =============================================

  Future<void> _processSale(double amountPaid) async {
    final sale = await _saleService.recordSale(
      cashierName: widget.cashierName,
      items: _cartService.items.toList(),
      amountPaid: amountPaid,
      paymentMethod: 'cash',
    );

    for (final item in _cartService.items) {
      _productService.decreaseStock(
          item.product.id, item.quantity);
    }

    _cartService.clearCart();
    setState(() {});

    HapticFeedback.heavyImpact();

    _showSaleConfirmation(sale);
  }

  void _showSaleConfirmation(dynamic sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check,
                    size: 45,
                    color: Colors.green.shade700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vente Enregistrée !',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Ticket #${sale.id.substring(sale.id.length - 6)}',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _summaryRow('Total',
                        '${sale.totalAmount.toStringAsFixed(0)} DZ'),
                    _summaryRow('Payé',
                        '${sale.amountPaid.toStringAsFixed(0)} DZ'),
                    _summaryRow('Monnaie',
                        '${sale.change.toStringAsFixed(0)} DZ'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 22),
                  label: const Text(
                    'NOUVELLE VENTE',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }

  // =============================================
  //              UTILITAIRES
  // =============================================

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError
            ? Colors.red.shade600
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFFF0F2F8),
      body: GestureDetector(
        onTap: () {
          _searchFocus.unfocus();
          setState(() => _showSearchResults = false);
        },
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildCartList(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // =============================================
  //               HEADER
  // =============================================

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16,
          MediaQuery.of(context).padding.top + 10, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade800,
            Colors.indigo.shade600
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ---- LIGNE 1 : Titre + Caissier ----
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Point de Vente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ma Caisse',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.cashierName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---- LIGNE 2 : Historique + Recherche + Scan ----
          Row(
            children: [
              // Bouton Historique
              GestureDetector(
                onTap: _openSalesHistory,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.history_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 10),

              // Barre de recherche
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                        color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Rechercher (utilisez % comme *)',
                      hintStyle: TextStyle(
                          color: Colors.white
                              .withOpacity(0.5),
                          fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white
                              .withOpacity(0.7)),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                      Icons.close,
                                      color:
                                          Colors.white70),
                                  onPressed: () {
                                    _searchController
                                        .clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _showSearchResults =
                                          false;
                                    });
                                  },
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Bouton Scanner
              GestureDetector(
                onTap: _openScanner,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================================
  //     WILDCARD CHIPS
  // =============================================

  Widget _wildcardChip(
      String pattern, String label, IconData icon) {
    return GestureDetector(
      onTap: () => _setSearchWithWildcard(pattern),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: Colors.indigo.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  //     SURLIGNER LE TEXTE
  // =============================================

  Widget _highlightMatch(String text, String query) {
    if (query.isEmpty || !query.contains('%')) {
      return Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14),
      );
    }

    final pattern =
        query.replaceAll('%', '.*').replaceAll('_', '.');
    final regex = RegExp('($pattern)', caseSensitive: false);
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14),
      );
    }

    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.indigo.shade700,
          backgroundColor: Colors.indigo.shade50,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  // =============================================
  //     RÉSULTATS DE RECHERCHE
  // =============================================

  Widget _buildSearchResults() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _wildcardChip(
                    '%', 'Tout', Icons.select_all),
                const SizedBox(width: 6),
                _wildcardChip('%a', 'Finit par "a"',
                    Icons.text_rotate_vertical),
                const SizedBox(width: 6),
                _wildcardChip('a%', 'Commence par "a"',
                    Icons.text_rotation_none),
                const SizedBox(width: 6),
                _wildcardChip('%%', 'Recherche avancée',
                    Icons.manage_search),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 60,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun produit trouvé',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.all(12),
                        margin: const EdgeInsets
                            .symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '💡 Astuce : utilisez % comme caractère générique',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                  color: Colors
                                      .indigo.shade700,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '%cola → Coca-Cola\n'
                              'coca% → Coca-Cola 1L\n'
                              '%col% → contient "col"',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                  color: Colors
                                      .indigo.shade500,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 16,
                            vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              const BorderRadius.only(
                            topLeft:
                                Radius.circular(16),
                            topRight:
                                Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list,
                                size: 16,
                                color: Colors
                                    .grey.shade500),
                            const SizedBox(width: 8),
                            Text(
                              '${_searchResults.length} résultat(s) pour "$_searchQuery"',
                              style: TextStyle(
                                  color: Colors
                                      .grey.shade600,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 4),
                          itemCount:
                              _searchResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(
                                  height: 1,
                                  color: Colors
                                      .grey.shade100),
                          itemBuilder:
                              (context, index) {
                            final product =
                                _searchResults[index];
                            final inCart = _cartService
                                .isInCart(product.id);
                            final lowStock =
                                product.stock <= 5;

                            return ListTile(
                              onTap: () =>
                                  _selectProduct(
                                      product),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .indigo.shade50,
                                  borderRadius:
                                      BorderRadius
                                          .circular(12),
                                ),
                                child: const Center(
                                  child: Text('📦',
                                      style: TextStyle(
                                          fontSize: 22)),
                                ),
                              ),
                              title: _highlightMatch(
                                  product.name,
                                  _searchQuery),
                              subtitle: Text(
                                '${product.price.toStringAsFixed(0)} DZ  •  '
                                '${lowStock ? "⚠️" : ""} Stock: ${product.stock}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: lowStock
                                      ? Colors.orange
                                          .shade700
                                      : Colors
                                          .grey.shade500,
                                ),
                              ),
                              trailing: inCart
                                  ? Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal:
                                                  10,
                                              vertical:
                                                  4),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors
                                            .indigo
                                            .shade50,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    20),
                                      ),
                                      child: Text(
                                        '${_cartService.getQuantity(product.id)}x',
                                        style: TextStyle(
                                            fontSize:
                                                12,
                                            color: Colors
                                                .indigo
                                                .shade700,
                                            fontWeight:
                                                FontWeight
                                                    .w600),
                                      ),
                                    )
                                  : Icon(
                                      Icons
                                          .add_circle_outline,
                                      color: Colors
                                          .indigo
                                          .shade400),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // =============================================
  //     PANIER (PRINCIPAL)
  // =============================================

  Widget _buildCartList() {
    if (_showSearchResults) {
      return _buildSearchResults();
    }

    if (_cartService.itemCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined,
                  size: 50,
                  color: Colors.indigo.shade200),
            ),
            const SizedBox(height: 20),
            Text(
              'Panier vide',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recherchez un produit ou scannez\nun code-barres pour commencer',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchResults =
                      _productService.getProducts();
                  _showSearchResults = true;
                });
              },
              icon: Icon(Icons.inventory_2_outlined,
                  color: Colors.indigo.shade400),
              label: Text('Voir tous les produits',
                  style: TextStyle(
                      color: Colors.indigo.shade600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                side: BorderSide(
                    color: Colors.indigo.shade200),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.receipt_long,
                  size: 20,
                  color: Colors.indigo.shade600),
              const SizedBox(width: 8),
              Text(
                'Articles (${_cartService.itemCount})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(18)),
                      title: const Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.red),
                          SizedBox(width: 10),
                          Text('Vider le panier'),
                        ],
                      ),
                      content: const Text(
                          'Voulez-vous supprimer tous les articles ?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx),
                          child: const Text('Non'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _cartService.clearCart();
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor:
                                Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        12)),
                          ),
                          child:
                              const Text('Oui, vider'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red),
                label: Text('Tout effacer',
                    style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            itemCount: _cartService.items.length,
            itemBuilder: (context, index) {
              final item = _cartService.items[index];
              return _buildCartItemCard(item, index);
            },
          ),
        ),
      ],
    );
  }

  // =============================================
  //     CARTE ARTICLE PANIER
  // =============================================

  Widget _buildCartItemCard(dynamic item, int index) {
    return Dismissible(
      key: Key(item.product.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        _cartService.removeProduct(item.product.id);
        setState(() {});
        _showSnackBar('${item.product.name} retiré',
            isError: true);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  _showEditQuantityDialog(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'x${item.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2D3436),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.product.price.toStringAsFixed(0)} DZ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyButton(
                  icon: Icons.remove,
                  onTap: () {
                    _cartService.decreaseQuantity(
                        item.product.id);
                    setState(() {});
                  },
                ),
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                _qtyButton(
                  icon: Icons.add,
                  onTap: () {
                    _cartService.increaseQuantity(
                        item.product.id);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(
                item.formattedTotal,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.indigo.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(
      {required IconData icon,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18, color: Colors.indigo.shade600),
        ),
      ),
    );
  }

  // =============================================
  //     MODIFIER QUANTITÉ
  // =============================================

  void _showEditQuantityDialog(dynamic item) {
    final TextEditingController qtyController =
        TextEditingController(
            text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Modifier quantité',
            style: TextStyle(
                color: Colors.indigo.shade800,
                fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.product.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Colors.indigo.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Colors.indigo.shade400,
                      width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty =
                  int.tryParse(qtyController.text) ?? 0;
              Navigator.pop(ctx);
              if (qty <= 0) {
                _cartService
                    .removeProduct(item.product.id);
              } else {
                _cartService
                    .removeProduct(item.product.id);
                for (int i = 0; i < qty; i++) {
                  _cartService.addProduct(item.product);
                }
              }
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12)),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  // =============================================
  //     BARRE INFÉRIEURE
  // =============================================

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.of(context).padding.bottom + 14),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cartService.totalQuantity} article(s)',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_cartService.itemCount} ligne(s)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${_cartService.formattedTotal} DZ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _cartService.itemCount > 0
                          ? Colors.indigo.shade800
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _cartService.itemCount > 0
                  ? _showPrintDialog
                  : null,
              icon: const Icon(Icons.print_rounded,
                  size: 24),
              label: const Text(
                'IMPRIMER LE TICKET',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade300,
                disabledForegroundColor:
                    Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                elevation:
                    _cartService.itemCount > 0 ? 4 : 0,
                shadowColor:
                    Colors.green.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}