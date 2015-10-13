﻿Imports System
Imports Roku.Node


Namespace Compiler

    Public Class Closure

        Public Shared Sub Capture(node As INode)

            Util.Traverse.NodesOnce(
                node,
                CType(node, IScopeNode),
                Sub(parent, ref, child, current, isfirst, next_)

                    If TypeOf child Is IScopeNode Then current = CType(child, IScopeNode)

                    If TypeOf child Is VariableNode Then

                        Dim var = CType(child, VariableNode)
                        If var.Scope IsNot current Then

                            var.ClosureEnvironment = True
                            Dim scope = current
                            Do
                                If TypeOf scope Is FunctionNode Then

                                    Dim func = CType(scope, FunctionNode)
                                    If func.Bind.ContainsKey(var.Scope) Then Exit Do
                                    func.Bind.Add(scope, True)
                                End If
                                scope = scope.Parent

                            Loop While var.Scope IsNot scope
                        End If
                    End If

                    next_(child, current)
                End Sub)

        End Sub

    End Class

End Namespace
