/// Utility to generate stable workflow step identifiers.
///
/// 使用时间戳作为步骤编号，避免删除、插入导致编号重排。
int generateStepId() => DateTime.now().millisecondsSinceEpoch;
