import 'package:flutter/material.dart';
import '../cadastros_base/tela_arvore_catalogo.dart'; // Importa a nossa árvore de 3 níveis!
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
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              // AGORA CHAMA A ÁRVORE DE CATEGORIAS
              Tab(icon: Icon(Icons.account_tree), text: 'Árvore de Categorias'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Catálogo de Insumos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // O motor de 3 níveis que criámos na etapa anterior
            TelaArvoreCatalogo(),
            TelaInsumos(),
          ],
        ),
      ),
    );
  }
}
