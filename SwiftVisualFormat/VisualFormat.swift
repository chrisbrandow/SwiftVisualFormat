//
//  VisualFormat.swift
//  SwiftVisualFormat
//
//  Created by Bridger Maxwell on 8/1/14.
//  Copyright (c) 2014 Bridger Maxwell. All rights reserved.
//

import UIKit


//TODO: It could work by making so 5.vf-| resolves to its own token, and so does |-5.vf. The prefix and postfix operators seem to have super precedence

// layoutHorizontal(|[imageView.vf >= 20.vf]-(>=0.vf!20.vf)-[imageView.vf]-50.vf-|)

@objc protocol ConstraintAble {
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint];
}

func layout(axis: UILayoutConstraintAxis, constraintAble: [ConstraintAble]) -> [NSLayoutConstraint] {
    return constraintAble[0].toConstraints(axis)
}


@objc protocol ViewContainingToken {
    var firstView: UIView? { get }
    var lastView: UIView? { get }
}

// This is either a token that directly is a view, or is a more complex token that is a composition of tokens, like [view]-space-[view]
class ViewToken: ViewContainingToken {
    let view: ALView
    init(view: ALView) {
        self.view = view
    }
    
    var firstView: UIView? {
    get {
        return self.view
    }
    }
    var lastView: UIView? {
    get {
        return self.view
    }
    }
}

class ConstantToken {
    let constant: CGFloat
    init(constant: CGFloat) {
        self.constant = constant
    }
}

// This is half of a space constraint, [view]-space
class ViewAndSpaceToken {
    let view: ViewContainingToken
    let space: ConstantToken
    let relation: NSLayoutRelation
    init(view: ViewContainingToken, space: ConstantToken, relation: NSLayoutRelation) {
        self.view = view
        self.space = space
        self.relation = relation
    }
}

class SpacedViewsConstraintToken: ConstraintAble, ViewContainingToken {
    let leadingView: ViewContainingToken
    let trailingView: ViewContainingToken
    let space: ConstantToken
    
    init(leadingView: ViewContainingToken, trailingView: ViewContainingToken, space: ConstantToken) {
        self.leadingView = leadingView
        self.trailingView = trailingView
        self.space = space
    }
    
    var firstView: UIView? {
    get {
        return self.leadingView.firstView
    }
    }
    var lastView: UIView? {
    get {
        return self.trailingView.lastView
    }
    }

    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let leadingView = self.leadingView.lastView {
            if let trailingView = self.trailingView.firstView {
                let space = self.space.constant
                
                var leadingAttribute: NSLayoutAttribute!
                var trailingAttribute: NSLayoutAttribute!
                if (axis == .Horizontal) {
                    leadingAttribute = .Leading
                    trailingAttribute = .Trailing
                } else {
                    leadingAttribute = .Top
                    leadingAttribute = .Bottom
                }
                
                var constraints = [NSLayoutConstraint(
                    item: trailingView, attribute: leadingAttribute,
                    relatedBy: .Equal,
                    toItem: leadingView, attribute: trailingAttribute,
                    multiplier: 1.0, constant: space)]
                
                if let leadingConstraint = self.leadingView as? ConstraintAble {
                    constraints += leadingConstraint.toConstraints(axis)
                }
                if let trailingConstraint = self.trailingView as? ConstraintAble {
                    constraints += trailingConstraint.toConstraints(axis)
                }

                return constraints
            }
        }
        
        NSException(name: NSInvalidArgumentException, reason: "This space constraint was between two view items that couldn't fit together. Weird?", userInfo: nil).raise()
        return [dummyConstraint] // To appease the compiler, which doesn't realize this branch dies
    }
}

class SizeConstantConstraintToken: ConstraintAble, ViewContainingToken {
    let view: ViewToken
    let size: ConstantToken
    let relation: NSLayoutRelation
    init(view: ViewToken, size: ConstantToken, relation: NSLayoutRelation) {
        self.view = view
        self.size = size
        self.relation = relation
    }
    
    var firstView: UIView? {
    get {
        return self.view.view
    }
    }
    var lastView: UIView? {
    get {
        return self.view.view
    }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        let view = self.view.view;
        let constant = self.size.constant
        let relation = self.relation
        
        var attribute: NSLayoutAttribute!
        if (axis == .Horizontal) {
            attribute = .Width
        } else {
            attribute = .Height
        }
        let constraint = NSLayoutConstraint(
            item: view, attribute: attribute,
            relatedBy: self.relation,
            toItem: nil, attribute: .NotAnAttribute,
            multiplier: 1.0, constant: constant)
        
        return [constraint]
    }
    
}

class SizeRelationConstraintToken: ConstraintAble, ViewContainingToken {
    let view: ViewToken
    let relatedView: ViewToken
    let relation: NSLayoutRelation
    init(view: ViewToken, relatedView: ViewToken, relation: NSLayoutRelation) {
        self.view = view
        self.relatedView = relatedView
        self.relation = relation
    }
    
    var firstView: UIView? {
    get {
        return self.view.view
    }
    }
    var lastView: UIView? {
    get {
        return self.view.view
    }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        let view = self.view.view;
        let relatedView = self.relatedView.view
        let relation = self.relation
        
        var attribute: NSLayoutAttribute!
        if (axis == .Horizontal) {
            attribute = .Width
        } else {
            attribute = .Height
        }
        return [ NSLayoutConstraint(
            item: view, attribute: attribute,
            relatedBy: self.relation,
            toItem: relatedView, attribute: attribute,
            multiplier: 1.0, constant: 0) ]
    }
}

// |[view]
class LeadingSuperviewConstraintToken: ConstraintAble, ViewContainingToken {
    let viewContainer: ViewContainingToken
    let space: ConstantToken
    init(viewContainer: ViewContainingToken, space: ConstantToken) {
        self.viewContainer = viewContainer
        self.space = space
    }
    var firstView: UIView? {
    get {
        return nil // No one can bind to our first view, is the superview
    }
    }
    var lastView: UIView? {
    get {
        return self.viewContainer.lastView
    }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let view = self.viewContainer.firstView {
            let constant = self.space.constant
            
            if let superview = view.superview {
                var constraint: NSLayoutConstraint!
                
                if (axis == .Horizontal) {
                        constraint = NSLayoutConstraint(
                            item: view, attribute: .Leading,
                            relatedBy: .Equal,
                            toItem: superview, attribute: .Leading,
                            multiplier: 1.0, constant: constant)
                } else {
                        constraint = NSLayoutConstraint(
                            item: view, attribute: .Top,
                            relatedBy: .Equal,
                            toItem: superview, attribute: .Top,
                            multiplier: 1.0, constant: constant)
                        
                        constraint = superview.al_top == view.al_top + constant
                }
                
                if let otherConstraint = viewContainer as?  ConstraintAble {
                    return otherConstraint.toConstraints(axis) + [constraint]
                } else {
                    return [constraint]
                }
            }
            NSException(name: NSInvalidArgumentException, reason: "You tried to create a constraint to \(view)'s superview, but it has no superview yet!", userInfo: nil).raise()
        }
        NSException(name: NSInvalidArgumentException, reason: "This superview bar | was before something that doesn't have a view. Weird?", userInfo: nil).raise()
        return [dummyConstraint] // To appease the compiler, which doesn't realize this branch dies
    }
    
    
}

// [view]|
class TrailingSuperviewConstraintTokenToken: ConstraintAble, ViewContainingToken {
    let viewContainer: ViewContainingToken
    let space: ConstantToken
    init(viewContainer: ViewContainingToken, space: ConstantToken) {
        self.viewContainer = viewContainer
        self.space = space
    }
    var firstView: UIView? {
    get {
        return self.viewContainer.firstView
    }
    }
    var lastView: UIView? {
    get {
        return nil // No one can bind to our last view, is the superview
    }
    }
    
    func toConstraints(axis: UILayoutConstraintAxis) -> [NSLayoutConstraint] {
        if let view = self.viewContainer.lastView {
            let constant = self.space.constant
            
            if let superview = view.superview {
                var constraint: NSLayoutConstraint!
                
                if (axis == .Horizontal) {
                    constraint = NSLayoutConstraint(
                        item: superview, attribute: .Trailing,
                        relatedBy: .Equal,
                        toItem: view, attribute: .Trailing,
                        multiplier: 1.0, constant: constant)
                } else {
                    constraint = NSLayoutConstraint(
                        item: superview, attribute: .Bottom,
                        relatedBy: .Equal,
                        toItem: view, attribute: .Bottom,
                        multiplier: 1.0, constant: constant)
                }
                
                if let otherConstraint = viewContainer as?  ConstraintAble {
                    return otherConstraint.toConstraints(axis) + [constraint]
                } else {
                    return [constraint]
                }
            }
            NSException(name: NSInvalidArgumentException, reason: "You tried to create a constraint to \(view)'s superview, but it has no superview yet!", userInfo: nil).raise()
        }
        NSException(name: NSInvalidArgumentException, reason: "This superview bar | was after something that doesn't have a view. Weird?", userInfo: nil).raise()
        
        return [dummyConstraint] // To appease the compiler, which doesn't realize this branch dies
    }
}

let RequiredPriority: Float = 1000 // For some reason, the linker can't find UILayoutPriorityRequired

operator prefix | {}
@prefix func | (tokenArray: [ViewContainingToken]) -> [LeadingSuperviewConstraintToken] {
    // |[view]
    return [LeadingSuperviewConstraintToken(viewContainer: tokenArray[0], space: ConstantToken(constant: 0))]
}

operator postfix | {}
@postfix func | (tokenArray: [ViewContainingToken]) -> [TrailingSuperviewConstraintTokenToken] {
    // [view]|
    return [TrailingSuperviewConstraintTokenToken(viewContainer: tokenArray[0], space: ConstantToken(constant: 0))]
}

operator infix >= {}
@infix func >= (left: ViewToken, right: ConstantToken) -> SizeConstantConstraintToken {
    return SizeConstantConstraintToken(view: left, size: right, relation: .GreaterThanOrEqual)
}
@infix func >= (left: ViewToken, right: ViewToken) -> SizeRelationConstraintToken {
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .GreaterThanOrEqual)
}

operator infix <= {}
@infix func <= (left: ViewToken, right: ConstantToken) -> SizeConstantConstraintToken {
    return SizeConstantConstraintToken(view: left, size: right, relation: .LessThanOrEqual)
}
@infix func <= (left: ViewToken, right: ViewToken) -> SizeRelationConstraintToken {
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .LessThanOrEqual)
}

operator infix == {}
@infix func == (left: ViewToken, right: ConstantToken) -> SizeConstantConstraintToken {
    return SizeConstantConstraintToken(view: left, size: right, relation: .Equal)
}
@infix func == (left: ViewToken, right: ViewToken) -> SizeRelationConstraintToken {
    return SizeRelationConstraintToken(view: left, relatedView: right, relation: .Equal)
}

operator infix - {}
@infix func - (left: [ViewContainingToken], right: ConstantToken) -> ViewAndSpaceToken {
    return ViewAndSpaceToken(view: left[0], space: right, relation: .Equal)
}

@infix func - (left: ViewAndSpaceToken, right: [ViewContainingToken]) -> [SpacedViewsConstraintToken] {
    return [SpacedViewsConstraintToken(leadingView: left.view, trailingView: right[0], space: left.space)]
}


operator postfix -| {}
@postfix func -| (token: ViewAndSpaceToken) -> [TrailingSuperviewConstraintTokenToken] {
    // [view]-5-|
    return [TrailingSuperviewConstraintTokenToken(viewContainer: token.view, space: token.space)]
}


let dummyConstraint = NSLayoutConstraint(item: nil, attribute: .NotAnAttribute, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 0)

extension ALView {
    var vf: ViewToken {
    get {
        return ViewToken(view: self)
    }
    }
}

extension CGFloat {
    var vf: ConstantToken {
    get {
        return ConstantToken(constant: self)
    }
    }
}

extension NSInteger {
    var vf: ConstantToken {
    get {
        return ConstantToken(constant: CGFloat(self))
    }
    }
}

