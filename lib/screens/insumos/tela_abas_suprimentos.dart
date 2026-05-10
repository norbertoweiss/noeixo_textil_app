import 'package:flutter/material.dart';
import '../fornecedores/tela_categorias_fornecedor.dart';
import 'tela_insumos.dart';

class TelaAbasSuprimentos extends StatelessWidget {
  const TelaAbasSuprimentos({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Categorias & Insumos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              Colors.indigo, // Cor original do seu botão no dashboard
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.account_tree), text: 'Classes e Subclasses'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Catálogo de Insumos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Importamos os ecrãs que já funcionam perfeitamente
            TelaCategoriasFornecedor(),
            TelaInsumos(),
          ],
        ),
      ),
    );
  }
}
