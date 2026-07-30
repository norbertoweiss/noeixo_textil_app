import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FiltroVendedorMulti extends StatefulWidget {
  final String empresaId;
  final List<String> vendedoresSelecionados;
  final Function(List<String>) onChanged;

  const FiltroVendedorMulti({
    super.key,
    required this.empresaId,
    required this.vendedoresSelecionados,
    required this.onChanged,
  });

  @override
  State<FiltroVendedorMulti> createState() => _FiltroVendedorMultiState();
}

class _FiltroVendedorMultiState extends State<FiltroVendedorMulti> {
  bool _carregando = true;
  List<Map<String, String>> _listaVendedores = [];

  @override
  void initState() {
    super.initState();
    _buscarVendedores();
  }

  Future<void> _buscarVendedores() async {
    // 1. O item primordial (A mina de ouro para distribuir) SEMPRE é construído primeiro
    List<Map<String, String>> listaFinal = [
      {'id': 'BOLSÃO', 'nome': '☁️ Bolsão / Fila de Distrib.'},
    ];

    try {
      // 2. Busca no banco SEM "orderBy" para não exigir a criação de um Índice Composto manual no Firebase.
      final snap = await FirebaseFirestore.instance
          .collection('vendedores')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('ativo', isEqualTo: true)
          .get();

      // 3. Organiza os dados temporariamente
      List<Map<String, String>> vendedoresDaEquipe = [];
      for (var doc in snap.docs) {
        var data = doc.data();
        vendedoresDaEquipe.add({
          'id': doc.id,
          'nome': data['nome_vendedor'] ?? 'Sem Nome',
        });
      }

      // 4. Faz a ordenação alfabética LOCALMENTE (rápido e seguro)
      vendedoresDaEquipe.sort((a, b) => a['nome']!.compareTo(b['nome']!));

      // 5. Junta a equipe debaixo da opção "Bolsão"
      listaFinal.addAll(vendedoresDaEquipe);

      setState(() {
        _listaVendedores = listaFinal;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao buscar vendedores dinamicamente: $e');
      // Em caso de qualquer pane, o Bolsão continua disponível para uso.
      setState(() {
        _listaVendedores = listaFinal;
        _carregando = false;
      });
    }
  }

  void _abrirPainelMultiSelecao() {
    List<String> selecaoTemporaria = List.from(widget.vendedoresSelecionados);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtrar por Vendedor(a)'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selecaoTemporaria.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8.0,
                                left: 16,
                              ),
                              child: Text(
                                '${selecaoTemporaria.length} selecionado(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _listaVendedores.length,
                              itemBuilder: (context, index) {
                                String idVendedor =
                                    _listaVendedores[index]['id']!;
                                String nomeVendedor =
                                    _listaVendedores[index]['nome']!;

                                return CheckboxListTile(
                                  title: Text(
                                    nomeVendedor,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  value: selecaoTemporaria.contains(idVendedor),
                                  activeColor: Colors.indigo,
                                  dense: true,
                                  onChanged: (bool? checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        selecaoTemporaria.add(idVendedor);
                                      } else {
                                        selecaoTemporaria.remove(idVendedor);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      setStateDialog(() => selecaoTemporaria.clear()),
                  child: const Text(
                    'Limpar Tudo',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onChanged(selecaoTemporaria);
                  },
                  child: const Text('Aplicar Filtro'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String textoVisor = 'Todos (Base Completa)';

    if (widget.vendedoresSelecionados.isNotEmpty) {
      List<String> nomesExibicao = [];

      for (String idSelecionado in widget.vendedoresSelecionados) {
        if (idSelecionado == 'BOLSÃO') {
          nomesExibicao.add('☁️ Bolsão');
        } else {
          // Procura o ID na lista carregada do Firebase
          var vendedor = _listaVendedores.firstWhere(
            (v) => v['id'] == idSelecionado,
            orElse: () => {'nome': 'Desconhecido'},
          );

          // Pega apenas o primeiro nome para deixar o visual mais limpo (ex: "Norberto weiss" -> "Norberto")
          String nomeCompleto = vendedor['nome'] ?? 'Desconhecido';
          String primeiroNome = nomeCompleto.split(' ').first;

          nomesExibicao.add(primeiroNome);
        }
      }

      // Junta todos os nomes com vírgula (ex: "Norberto, Sergio")
      textoVisor = nomesExibicao.join(', ');
    }

    return InkWell(
      onTap: _carregando ? null : _abrirPainelMultiSelecao,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Carteira / Vendedores',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                textoVisor,
                style: TextStyle(
                  color: widget.vendedoresSelecionados.isEmpty
                      ? Colors.black87
                      : Colors.indigo,
                  fontWeight: widget.vendedoresSelecionados.isEmpty
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _carregando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
