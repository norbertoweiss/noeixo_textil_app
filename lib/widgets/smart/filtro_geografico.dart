import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FiltroGeograficoMulti extends StatefulWidget {
  final String ufSelecionada;
  final List<String> cidadesSelecionadas;
  final Function(String uf, List<String> cidades) onChanged;

  const FiltroGeograficoMulti({
    super.key,
    required this.ufSelecionada,
    required this.cidadesSelecionadas,
    required this.onChanged,
  });

  @override
  State<FiltroGeograficoMulti> createState() => _FiltroGeograficoMultiState();
}

class _FiltroGeograficoMultiState extends State<FiltroGeograficoMulti> {
  final List<String> _listaUFs = [
    'Todas',
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  List<String> _cidadesDoEstado = [];
  bool _carregandoCidades = false;

  Future<void> _buscarCidadesIBGE(String uf) async {
    if (uf == 'Todas') {
      setState(() => _cidadesDoEstado = []);
      return;
    }

    setState(() => _carregandoCidades = true);
    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/ibge/municipios/v1/$uf'),
      );
      if (response.statusCode == 200) {
        final List dados = json.decode(response.body);
        setState(() {
          _cidadesDoEstado = dados
              .map((c) => (c['nome'] as String).toUpperCase())
              .toList();
          _cidadesDoEstado.sort();
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar cidades: $e');
    } finally {
      if (mounted) setState(() => _carregandoCidades = false);
    }
  }

  void _abrirPainelMultiSelecao() {
    if (widget.ufSelecionada == 'Todas') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione um Estado (UF) primeiro para ver as cidades.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> selecaoTemporaria = List.from(widget.cidadesSelecionadas);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Cidades de ${widget.ufSelecionada}'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: _carregandoCidades
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
                                '${selecaoTemporaria.length} cidade(s) selecionada(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _cidadesDoEstado.length,
                              itemBuilder: (context, index) {
                                String cidade = _cidadesDoEstado[index];
                                return CheckboxListTile(
                                  title: Text(
                                    cidade,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  value: selecaoTemporaria.contains(cidade),
                                  activeColor: Colors.indigo,
                                  dense: true,
                                  onChanged: (bool? checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        selecaoTemporaria.add(cidade);
                                      } else {
                                        selecaoTemporaria.remove(cidade);
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
                    widget.onChanged(widget.ufSelecionada, selecaoTemporaria);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Estado (UF)',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  isExpanded: true,
                  value: widget.ufSelecionada,
                  items: _listaUFs.map((String uf) {
                    return DropdownMenuItem<String>(value: uf, child: Text(uf));
                  }).toList(),
                  onChanged: (novaUf) {
                    if (novaUf != null) {
                      widget.onChanged(
                        novaUf,
                        [],
                      ); // Reseta as cidades ao trocar a UF
                      _buscarCidadesIBGE(novaUf);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _abrirPainelMultiSelecao,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Cidades',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.cidadesSelecionadas.isEmpty
                            ? 'Todas as Cidades'
                            : widget.cidadesSelecionadas.join(', '),
                        style: TextStyle(
                          color: widget.cidadesSelecionadas.isEmpty
                              ? Colors.grey.shade700
                              : Colors.indigo,
                          fontWeight: widget.cidadesSelecionadas.isEmpty
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
