import 'package:flutter/material.dart';
import 'form_entrada_manual.dart'; // Importamos o novo formulário

class TelaEntradaConferencia extends StatelessWidget {
  const TelaEntradaConferencia({super.key});

  void _abrirOpcoesEntrada(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja registrar a entrada?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.qr_code_scanner, color: Colors.white),
                  ),
                  title: const Text(
                    'Importar XML Automático',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Lê os itens, cruza com o pedido e gera o financeiro sozinho.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Módulo de leitura de XML será ativado em breve.',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.keyboard, color: Colors.teal),
                  ),
                  title: const Text(
                    'Digitação Manual',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Para Notas Frias, Recibos ou Ajustes de Saldo.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FormEntradaManual(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada e Conferência'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Neste módulo serão registadas as entradas de fornecedores. O sistema aceita XML (oficial) ou registro manual (notas simples), garantindo que o estoque reflita a realidade física.',
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Últimas Entradas Registadas:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma entrada processada hoje.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () => _abrirOpcoesEntrada(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Registrar Entrada',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
