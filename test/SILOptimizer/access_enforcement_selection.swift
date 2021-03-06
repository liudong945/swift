// RUN: %target-swift-frontend -enforce-exclusivity=checked -Onone -emit-sil -parse-as-library %s -Xllvm -debug-only=access-enforcement-selection 2>&1 | %FileCheck %s
// REQUIRES: asserts

// This is a source-level test because it helps bring up the entire -Onone pipeline with the access markers.

public func takesInout(_ i: inout Int) {
  i = 42
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection10takesInoutySizF
// CHECK: Static Access: %{{.*}} = begin_access [modify] [static] %{{.*}} : $*Int

// Helper taking a basic, no-escape closure.
func takeClosure(_: ()->Int) {}

// Helper taking a basic, no-escape closure.
func takeClosureAndInout(_: inout Int, _: ()->Int) {}

// Helper taking an escaping closure.
func takeEscapingClosure(_: @escaping ()->Int) {}

// Generate an alloc_stack that escapes into a closure.
public func captureStack() -> Int {
  // Use a `var` so `x` isn't treated as a literal.
  var x = 3
  takeClosure { return x }
  return x
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection12captureStackSiyF
// Dynamic access for `return x`. Since the closure is non-escaping, using
// dynamic enforcement here is more conservative than it needs to be -- static
// is sufficient here.
// CHECK: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int

// The access inside the closure is dynamic, until we have the logic necessary to
// prove that no other closures are passed to `takeClosure` that may write to
// `x`.
//
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection12captureStackSiyFSiycfU_
// CHECK: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int


// Generate an alloc_stack that does not escape into a closure.
public func nocaptureStack() -> Int {
  var x = 3
  takeClosure { return 5 }
  return x
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection14nocaptureStackSiyF
// Static access for `return x`.
// CHECK: Static Access: %{{.*}} = begin_access [read] [static] %{{.*}} : $*Int
//
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection14nocaptureStackSiyFSiycfU_

// Generate an alloc_stack that escapes into a closure while an access is
// in progress.
public func captureStackWithInoutInProgress() -> Int {
  // Use a `var` so `x` isn't treated as a literal.
  var x = 3
  takeClosureAndInout(&x) { return x }
  return x
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection31captureStackWithInoutInProgressSiyF
// Dynamic access for `&x`. This must be dynamic so that we catch the conflict
// in the closure.
// CHECK-DAG: Dynamic Access: %{{.*}} = begin_access [modify] [dynamic] %{{.*}} : $*Int
// Dynamic access for `return x`. This is more conservative than it needs
// to be; it can be static.
// CHECK-DAG: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int
//
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection31captureStackWithInoutInProgressSiyFSiycfU_
// CHECK: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int

// Generate an alloc_box that escapes into a closure.
public func captureBox() -> Int {
  var x = 3
  takeEscapingClosure { x = 4; return x }
  return x
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection10captureBoxSiyF
// Dynamic access for `return x`.
// CHECK: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int
// CHECK-LABEL: _T028access_enforcement_selection10captureBoxSiyFSiycfU_

// Generate a closure in which the @inout_aliasing argument
// escapes to an @inout function `bar`.
public func recaptureStack() -> Int {
  var x = 3
  takeClosure { takesInout(&x); return x }
  return x
}
// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection14recaptureStackSiyF
//
// Dynamic access for `return x`. This is more conservative than it needs
// to be; static is sufficient.
// CHECK: Dynamic Access:   %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int

// CHECK-LABEL: Access Enforcement Selection in _T028access_enforcement_selection14recaptureStackSiyFSiycfU_
//
// The first [modify] access inside the closure must be dynamic. It enforces the
// @inout argument.
// CHECK: Dynamic Access: %{{.*}} = begin_access [modify] [dynamic] %{{.*}} : $*Int
//
// The second [read] access is only dynamic because the analysis isn't strong
// enough to prove otherwise. Same as `captureStack` above.
//
// CHECK: Dynamic Access: %{{.*}} = begin_access [read] [dynamic] %{{.*}} : $*Int
