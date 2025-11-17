import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Ajuste conforme o caminho do seu arquivo main

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isSaving = false;

  /// NOVO → define se o grupo é privado ou público
  bool _isPrivate = true;

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
      final creatorId = supabase.auth.currentUser?.id;
      if (creatorId == null) throw 'Usuário não autenticado';

      // 1) Cria o grupo já com campo is_private
      final resp = await supabase
          .from('groups')
          .insert({
            'name': name,
            'creator_id': creatorId,
            'is_private': _isPrivate, // ← ADICIONADO AQUI
          })
          .select()
          .single();

      final String groupId = resp['id'] as String;

      // 2) Insere os membros selecionados
      final members = <Map<String, dynamic>>[];

      for (final id in _selectedUserIds) {
        members.add({
          'group_id': groupId,
          'profile_id': id,
        });
      }

      // adiciona o criador automaticamente
      members.add({
        'group_id': groupId,
        'profile_id': creatorId,
      });

      await supabase.from('group_members').insert(members);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo criado com sucesso!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar grupo: $e')),
        );
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final currentUserId = supabase.auth.currentUser!.id;
    final resp = await supabase
        .from('profiles')
        .select('id, username')
        .neq('id', currentUserId);

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

            const SizedBox(height: 16),

            // 🔥 SWITCH PRIVADO/PÚBLICO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grupo privado'),
                Switch(
                  value: _isPrivate,
                  onChanged: (v) {
                    setState(() => _isPrivate = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar usuários: ${snapshot.error}',
                      ),
                    );
                  }

                  final users = snapshot.data ?? [];

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
