Imports Roku.Node


Namespace Manager

    Public Class RkByNameWithReceiver
        Inherits RkByName

        Public Overridable Property Receiver As IEvaluableNode

        Public Overrides Function ToString() As String

            Return If(Me.Receiver Is Nothing, $"{Me.Name}", $"{Me.Receiver}.{Me.Name}")
        End Function
    End Class

End Namespace
