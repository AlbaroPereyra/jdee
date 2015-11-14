//
// Generated by JTB 1.1.2
//

package jde.parser.syntaxtree;

/**
 * Grammar production:
 * <PRE>
 * f0 -> ( "static" | "abstract" | "final" | "public" | "protected" | "private" )*
 * f1 -> UnmodifiedClassDeclaration()
 * </PRE>
 */
public class NestedClassDeclaration implements Node {
   public NodeListOptional f0;
   public UnmodifiedClassDeclaration f1;

   public NestedClassDeclaration(NodeListOptional n0, UnmodifiedClassDeclaration n1) {
      f0 = n0;
      f1 = n1;
   }

   public void accept(jde.parser.visitor.Visitor v) {
      v.visit(this);
   }
}
