import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // usa o supabase global

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome do grupo')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ownerId = supabase.auth.currentUser?.id;
      if (ownerId == null) throw 'Usuário não autenticado';

      // 1) Criar grupo
      final resp = await supabase
          .from('groups')
          .insert({
            'name': name,
            'owner_id': ownerId, // <-- CORRETO
          })
          .select()
          .single();

      final String groupId = resp['id'];

      // 2) Criar lista de membros
      final members = <Map<String, dynamic>>[];

      // adicionar membros selecionados
      for (final id in _selectedUserIds) {
        members.add({
          'group_id': groupId,
          'user_id': id, // <-- CORRIGIDO
        });
      }

      // adicionar o dono também
      members.add({
        'group_id': groupId,
        'user_id': ownerId, // <-- CORRIGIDO
      });

      // inserir tudo de uma vez
      await supabase.from('group_members').insert(members);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo criado com sucesso!')),
      );

      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar grupo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final resp = await supabase.from('profiles').select('id, username');
    return List<Map<String, dynamic>>.from(resp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Grupo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do grupo'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return const Center(child: Text('Nenhum usuário encontrado.'));
                  }
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      final id = u['id'] as String;
                      final username = u['username'] as String? ?? 'Usuário';
                      final selected = _selectedUserIds.contains(id);

                      return CheckboxListTile(
                        value: selected,
                        title: Text(username),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedUserIds.add(id);
                            } else {
                              _selectedUserIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createGroup,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar Grupo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
