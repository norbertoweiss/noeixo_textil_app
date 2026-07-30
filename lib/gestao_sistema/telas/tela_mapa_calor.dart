import 'dart:ui'; // <- Importante para habilitar o mouse na Web
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/motor_cartografico.dart';

class TelaMapaCalor extends StatefulWidget {
  final String empresaId;
  const TelaMapaCalor({super.key, required this.empresaId});

  @override
  State<TelaMapaCalor> createState() => _TelaMapaCalorState();
}

class _TelaMapaCalorState extends State<TelaMapaCalor> {
  // Dados salvos na memória para não gastar leitura do Firebase à toa
  List<Map<String, dynamic>> _listaClientes = [];
  List<Map<String, dynamic>> _listaRegioes = [];

  List<Polygon> _poligonosMunicipios = [];

  bool _carregandoBanco = true;
  bool _processandoMapa = false;

  // Lista com todos os estados. Começa com 'sc' ativado.
  final List<String> _todosEstados = [
    'ac',
    'al',
    'ap',
    'am',
    'ba',
    'ce',
    'df',
    'es',
    'go',
    'ma',
    'mt',
    'ms',
    'mg',
    'pa',
    'pb',
    'pr',
    'pe',
    'pi',
    'rj',
    'rn',
    'rs',
    'ro',
    'rr',
    'sc',
    'sp',
    'se',
    'to',
  ];
  List<String> _estadosAtivos = ['sc'];

  @override
  void initState() {
    super.initState();
    _buscarDadosFirebase();
  }

  // PASSO 1: Busca os dados no Firebase UMA ÚNICA VEZ
  Future<void> _buscarDadosFirebase() async {
    try {
      final snapClientes = await FirebaseFirestore.instance
          .collection('clientes')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get();

      _listaClientes = snapClientes.docs
          .map((d) => d.data())
          .where((data) => data['ativo'] == true)
          .toList();

      final snapRegioes = await FirebaseFirestore.instance
          .collection('regioes_venda')
          .get();

      _listaRegioes = snapRegioes.docs
          .map((d) => d.data())
          .where((data) => data['ativo'] == true)
          .toList();

      if (mounted) {
        setState(() {
          _carregandoBanco = false;
        });
      }

      // Assim que baixar os dados, manda desenhar o mapa do estado inicial
      _desenharMapa();
    } catch (e) {
      debugPrint('🚨 ERRO AO BUSCAR DADOS DO FIREBASE: $e');
      if (mounted) setState(() => _carregandoBanco = false);
    }
  }

  // PASSO 2: Desenha o mapa rapidamente na memória sempre que trocar de estado
  Future<void> _desenharMapa() async {
    if (!mounted) return;
    setState(() => _processandoMapa = true);

    try {
      final poligonos = await MotorCartografico.gerarMapaCalor(
        clientes: _listaClientes,
        regioes: _listaRegioes,
        estadosSelecionados: _estadosAtivos,
      );

      if (mounted) {
        setState(() {
          _poligonosMunicipios = poligonos;
          _processandoMapa = false;
        });
      }
    } catch (e) {
      debugPrint('🚨 ERRO AO DESENHAR MAPA: $e');
      if (mounted) setState(() => _processandoMapa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Calor - Expansão Nacional'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _carregandoBanco
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Baixando dados logísticos da nuvem...'),
                ],
              ),
            )
          : Column(
              children: [
                // BARRA DE SELEÇÃO DE ESTADOS COM SCROLL HABILITADO PARA MOUSE
                Container(
                  height: 60,
                  color: Colors.grey.shade100,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind
                            .touch, // Permite arrastar com o dedo (celular)
                        PointerDeviceKind
                            .mouse, // Permite clicar e arrastar com o mouse (Web/Desktop)
                      },
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _todosEstados.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        String sigla = _todosEstados[index];
                        bool ativo = _estadosAtivos.contains(sigla);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 8.0,
                          ),
                          child: FilterChip(
                            label: Text(sigla.toUpperCase()),
                            labelStyle: TextStyle(
                              color: ativo
                                  ? Colors.white
                                  : Colors.indigo.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                            selected: ativo,
                            selectedColor: Colors.indigo,
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.white,
                            shape: StadiumBorder(
                              side: BorderSide(color: Colors.indigo.shade200),
                            ),
                            onSelected: (selecionado) {
                              setState(() {
                                if (selecionado) {
                                  _estadosAtivos.add(sigla);
                                } else {
                                  // Evita que o usuário desmarque todos e a tela fique vazia
                                  if (_estadosAtivos.length > 1) {
                                    _estadosAtivos.remove(sigla);
                                  }
                                }
                              });
                              // Refaz o desenho instantaneamente
                              _desenharMapa();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // O MAPA EM SI
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: const MapOptions(
                          initialCenter: LatLng(-27.2423, -50.2188),
                          initialZoom: 6.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.noeixo.app',
                          ),
                          PolygonLayer(polygons: _poligonosMunicipios),
                        ],
                      ),

                      // Mostra um aviso enquanto junta os mapas
                      if (_processandoMapa)
                        Container(
                          color: Colors.white.withOpacity(0.7),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

      // LEGENDA INFERIOR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ItemLegenda(cor: Colors.blue, texto: 'Região c/ Cliente'),
            _ItemLegenda(cor: Colors.grey, texto: 'Ocioso (Sem cliente)'),
            _ItemLegenda(cor: Colors.orange, texto: 'Avulso (Sem região)'),
          ],
        ),
      ),
    );
  }
}

class _ItemLegenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _ItemLegenda({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: cor,
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
