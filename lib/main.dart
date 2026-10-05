import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const BatalhaDeIdeiasApp(firebaseConfigurado: true));
  } catch (e) {
    runApp(BatalhaDeIdeiasApp(
      firebaseConfigurado: false,
      erroFirebase: e.toString(),
    ));
  }
}

class BatalhaDeIdeiasApp extends StatelessWidget {
  final bool firebaseConfigurado;
  final String? erroFirebase;

  const BatalhaDeIdeiasApp({
    super.key,
    required this.firebaseConfigurado,
    this.erroFirebase,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batalha de Ideias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        scaffoldBackgroundColor: const Color(0xFFF7F5FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2),
          ),
        ),
      ),
      home: firebaseConfigurado
          ? const HomePage()
          : FirebaseConfigPage(erro: erroFirebase),
    );
  }
}

class FirebaseConfigPage extends StatelessWidget {
  final String? erro;

  const FirebaseConfigPage({super.key, this.erro});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Firebase ainda não está configurado',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No terminal do projeto, execute "flutterfire configure" e selecione o seu projeto Firebase. Depois execute "flutter run" novamente.',
                    ),
                    const SizedBox(height: 16),
                    const SelectableText(
                      'Comandos principais:\n\n'
                      'dart pub global activate flutterfire_cli\n'
                      'flutterfire configure\n'
                      'flutter pub get\n'
                      'flutter run -d chrome',
                    ),
                    if (erro != null) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Detalhes técnicos'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(erro!),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ideias =>
      _firestore.collection('ideias');

  Stream<QuerySnapshot<Map<String, dynamic>>> get _ideiasStream =>
      _ideias.orderBy('votos', descending: true).snapshots();

  Future<void> _abrirCadastro() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const CadastroIdeiaSheet(),
    );
  }

  Future<void> _votar(String id) async {
    try {
      await _ideias.doc(id).update({
        'votos': FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível votar: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _excluir(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final dados = doc.data() ?? {};
    final titulo = dados['titulo']?.toString() ?? 'esta ideia';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ideia?'),
        content: Text('A ideia "$titulo" será removida do Firebase para todos os usuários.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _ideias.doc(doc.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia excluída com sucesso.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir: ${e.message ?? e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_rounded),
            SizedBox(width: 10),
            Text('Batalha de Ideias', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        icon: const Icon(Icons.add),
        label: const Text('Nova ideia'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ideiasStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MensagemCentral(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar as ideias',
              mensagem: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final ideiaMaisVotada = docs.isEmpty ? null : docs.first;

          return RefreshIndicator(
            onRefresh: () async {
              await _ideias.get(const GetOptions(source: Source.server));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _RankingCard(doc: ideiaMaisVotada),
                const SizedBox(height: 20),
                Text(
                  'Todas as ideias',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const _MensagemCentral(
                    icone: Icons.lightbulb_outline,
                    titulo: 'Nenhuma ideia ainda',
                    mensagem: 'Cadastre a primeira ideia e comece a batalha!',
                  )
                else
                  ...docs.map(
                    (doc) => IdeiaCard(
                      doc: doc,
                      onVotar: () => _votar(doc.id),
                      onExcluir: () => _excluir(doc),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>>? doc;

  const _RankingCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    if (doc == null) {
      return Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '🏆 IDEIA MAIS VOTADA\nCadastre uma ideia para começar o ranking.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dados = doc!.data() ?? {};
    final titulo = dados['titulo']?.toString() ?? 'Sem título';
    final votos = _intValue(dados['votos']);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDEIA MAIS VOTADA',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text('$votos ${votos == 1 ? 'voto' : 'votos'}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IdeiaCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onVotar;
  final VoidCallback onExcluir;

  const IdeiaCard({
    super.key,
    required this.doc,
    required this.onVotar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final dados = doc.data() ?? {};
    final titulo = dados['titulo']?.toString() ?? 'Sem título';
    final descricao = dados['descricao']?.toString() ?? '';
    final autor = dados['autor']?.toString() ?? 'Autor não informado';
    final votos = _intValue(dados['votos']);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (valor) {
                    if (valor == 'excluir') onExcluir();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'excluir',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Autor: $autor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(descricao),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 22),
                const SizedBox(width: 7),
                Text(
                  '$votos ${votos == 1 ? 'voto' : 'votos'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onVotar,
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('VOTAR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CadastroIdeiaSheet extends StatefulWidget {
  const CadastroIdeiaSheet({super.key});

  @override
  State<CadastroIdeiaSheet> createState() => _CadastroIdeiaSheetState();
}

class _CadastroIdeiaSheetState extends State<CadastroIdeiaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _autorController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _autorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      await FirebaseFirestore.instance.collection('ideias').add({
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'autor': _autorController.text.trim(),
        'votos': 0,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia cadastrada com sucesso!')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: ${e.message ?? e.code}')),
      );
    }
  }

  String? _obrigatorio(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe $campo.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cadastrar nova ideia',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => _obrigatorio(v, 'o título'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descricaoController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => _obrigatorio(v, 'a descrição'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _autorController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do autor',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => _obrigatorio(v, 'o nome do autor'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_salvando ? 'Salvando...' : 'SALVAR IDEIA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MensagemCentral extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;

  const _MensagemCentral({
    required this.icone,
    required this.titulo,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          Icon(icone, size: 52),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(mensagem, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}